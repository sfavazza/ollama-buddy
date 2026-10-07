;;; ollama-buddy-tools-test.el --- Tests for tool schemas -*- lexical-binding: t; -*-

;;; Commentary:

;; ERT tests for ollama-buddy-tools.el
;; Run with: make test-tools

;;; Code:

(require 'ert)
(require 'test-helper)
(require 'ollama-buddy-tools)

(defmacro ollama-buddy-tools-test--with-fictitious-tools (&rest body)
  "Run BODY with isolated registry containing fictitious tools."
  (declare (indent 0) (debug t))        ; simiplify debugging
  `(let ((ollama-buddy-tools--registry (make-hash-table :test 'equal))
         (ollama-buddy-tools--schema-cache nil)
         (ollama-buddy-tools--responses-schema-cache nil)
         (ollama-buddy-tools--schema-cache-safe-mode nil)
         (ollama-buddy-tools-safe-mode nil))
     (ollama-buddy-tools-register
      "test_lookup"
      "Look up a fictitious record."
      '((type . "object")
        (required . ["query"])
        (properties . ((query . ((type . "string")
                                 (description . "Record query."))))))
      (lambda (_args) "lookup result")
      t)
     (ollama-buddy-tools-register
      "test_update"
      "Update a fictitious record."
      '((type . "object")
        (required . ["id" "value"])
        (properties . ((id . ((type . "integer")
                              (description . "Record identifier.")))
                       (value . ((type . "string")
                                 (description . "New record value."))))))
      (lambda (_args) "update result"))
     ,@body))

(defconst ollama-buddy-tools-test--expected-functions
  '(((name . "test_lookup")
     (description . "Look up a fictitious record.")
     (parameters . ((type . "object")
                    (required . ["query"])
                    (properties . ((query . ((type . "string")
                                             (description . "Record query."))))))))
    ((name . "test_update")
     (description . "Update a fictitious record.")
     (parameters . ((type . "object")
                    (required . ["id" "value"])
                    (properties . ((id . ((type . "integer")
                                          (description . "Record identifier.")))
                                   (value . ((type . "string")
                                             (description . "New record value.")))))))))
  "Expected shared function definitions, independent of API wrapper.")

(defun ollama-buddy-tools-test--tool-name (tool)
  "Return TOOL name for either supported schema shape."
  (or (alist-get 'name tool)
      (alist-get 'name (alist-get 'function tool))))

(defun ollama-buddy-tools-test--sorted-schema (schema)
  "Return SCHEMA vector sorted by tool name."
  (vconcat
   (sort (append schema nil)
         (lambda (left right)
           (string< (ollama-buddy-tools-test--tool-name left)
                    (ollama-buddy-tools-test--tool-name right))))))

(defun ollama-buddy-tools-test--expected-schema (api-style)
  "Build expected schema for API-STYLE from shared tool definitions."
  (vconcat
   (mapcar (lambda (function-schema)
             (if (eq api-style 'responses)
                 `((type . "function") ,@function-schema)
               `((type . "function") (function . ,function-schema))))
           ollama-buddy-tools-test--expected-functions)))

(defun ollama-buddy-tools-test--assert-schema (api-style)
  "Assert generated schema for API-STYLE matches its complete expected shape."
  (ollama-buddy-tools-test--with-fictitious-tools
    (let ((actual (ollama-buddy-tools--generate-schema api-style))
          (expected (ollama-buddy-tools-test--expected-schema api-style)))
      ;; Full equality checks descriptions, parameters, and API-specific wrapper.
      (should (equal expected
                     (ollama-buddy-tools-test--sorted-schema actual))))))

(ert-deftest ollama-buddy-tools-test-chat-completions-schema ()
  "Generate schema in Chat Completions function-wrapper format."
  :tags '(tools)
  (ollama-buddy-tools-test--assert-schema 'chat-completions))

(ert-deftest ollama-buddy-tools-test-responses-schema ()
  "Generate schema in Responses API function format."
  :tags '(tools)
  (ollama-buddy-tools-test--assert-schema 'responses))

(provide 'ollama-buddy-tools-test)
;;; ollama-buddy-tools-test.el ends here
