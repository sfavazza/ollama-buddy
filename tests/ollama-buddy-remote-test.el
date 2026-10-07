;;; ollama-buddy-remote-test.el --- Tests for remote API payloads -*- lexical-binding: t; -*-

;;; Commentary:

;; ERT tests for ollama-buddy-remote.el
;; Run with: make test-remote

;;; Code:

(require 'ert)
(require 'test-helper)
(require 'ollama-buddy-remote)

(defun ollama-buddy-test--capture-openai-payload (api-style)
  "Capture the JSON payload generated for API-STYLE."
  (let (captured)
    (let ((ollama-buddy-streaming-enabled nil)
          (ollama-buddy-history-enabled nil)
          (ollama-buddy--current-model nil)
          (ollama-buddy--current-attachments nil)
          (ollama-buddy--conversation-history-by-model
           (make-hash-table :test 'equal))
          (ollama-buddy--current-system-prompt nil)
          (ollama-buddy--current-tone nil)
          (ollama-buddy-tone-alist nil)
          (ollama-buddy-global-system-prompt-enabled nil)
          (ollama-buddy-global-system-prompt nil)
          (ollama-buddy--tool-call-iteration 0)
          (ollama-buddy--chat-buffer "*ollama-buddy-test*")
          (ollama-buddy-remote--tool-continuation-p nil))
      (cl-letf (((symbol-function 'ollama-buddy-remote--prepare-chat-buffer)
                 (lambda (_provider-name) 1))
                ((symbol-function 'url-retrieve)
                 (lambda (&rest _args)
                   (setq captured url-request-data))))
        (ollama-buddy-remote--openai-send-payload
         "Hello" "a:gpt-test"
         (list :prefix "a:"
               :api-key "test-key"
               :endpoint "https://example.test/responses"
               :temperature 0.2
               :max-tokens 123
               :default-model "gpt-test"
               :provider-name "Test"
               :api-style api-style
               :token-count-var 'ollama-buddy-test-token-count))
        (let ((json-object-type 'alist)
              (json-array-type 'vector)
              (json-key-type 'symbol))
          (json-read-from-string captured))))))

(ert-deftest ollama-buddy-remote-test-chat-completions-payload ()
  "Generate the legacy Chat Completions request shape."
  :tags '(api provider)
  (let ((payload
         (ollama-buddy-test--capture-openai-payload 'chat-completions)))
    (should (alist-get 'messages payload))
    (should-not (alist-get 'input payload))
    (should (= 123 (alist-get 'max_tokens payload)))
    (should-not (alist-get 'max_output_tokens payload))
    (should (equal "gpt-test" (alist-get 'model payload)))))

(ert-deftest ollama-buddy-remote-test-responses-payload ()
  "Generate the Responses API request shape."
  :tags '(api provider)
  (let ((payload
         (ollama-buddy-test--capture-openai-payload 'responses)))
    (should (alist-get 'input payload))
    (should-not (alist-get 'messages payload))
    (should (= 123 (alist-get 'max_output_tokens payload)))
    (should-not (alist-get 'max_tokens payload))
    (should (equal "gpt-test" (alist-get 'model payload)))))

(ert-deftest ollama-buddy-remote-test-chat-completions-sse ()
  "Extract content from a Chat Completions SSE chunk."
  :tags '(api provider)
  (should (equal "Hello"
                 (ollama-buddy-remote--openai-extract-content
                  "{\"choices\":[{\"delta\":{\"content\":\"Hello\"}}]}"))))

(ert-deftest ollama-buddy-remote-test-responses-sse ()
  "Extract text deltas and ignore Responses lifecycle events."
  :tags '(api provider)
  (should (equal "Hello"
                 (ollama-buddy-remote--responses-extract-content
                  "{\"type\":\"response.output_text.delta\",\"delta\":\"Hello\"}")))
  (should-not
   (ollama-buddy-remote--responses-extract-content
    "{\"type\":\"response.completed\",\"response\":{\"status\":\"completed\"}}")))

(ert-deftest ollama-buddy-remote-test-responses-output-text ()
  "Extract non-streamed text from a Responses output array."
  :tags '(api provider)
  (let ((output [((type . "message")
                  (content . [((type . "output_text") (text . "Hello"))
                              ((type . "output_text") (text . " world"))]))]))
    (should (equal "Hello world"
                   (ollama-buddy-remote--responses-output-text output)))))

(ert-deftest ollama-buddy-remote-test-responses-output-tool-call ()
  "Convert a non-streamed Responses function call to tool-call history shape."
  :tags '(api provider)
  (let ((calls
         (ollama-buddy-remote--responses-output-tool-calls
          [((type . "function_call")
            (id . "fc_item_1")
            (call_id . "call_1")
            (name . "lookup")
            (arguments . "{\"q\":\"Emacs\"}"))])))
    (should (equal "call_1" (alist-get 'id (car calls))))
    (should (equal "lookup"
                   (alist-get 'name (alist-get 'function (car calls)))))
    (should (equal "{\"q\":\"Emacs\"}"
                   (alist-get 'arguments (alist-get 'function (car calls)))))))

(ert-deftest ollama-buddy-remote-test-responses-streaming-tool-call ()
  "Accumulate Responses function-call argument events."
  :tags '(api provider)
  (let ((ollama-buddy-remote--streaming-tool-call-acc nil))
    (ollama-buddy-remote--responses-extract-content-with-tools
     "{\"type\":\"response.output_item.added\",\"item\":{\"type\":\"function_call\",\"id\":\"fc_item_1\",\"call_id\":\"call_1\",\"name\":\"lookup\",\"arguments\":\"\"}}")
    (ollama-buddy-remote--responses-extract-content-with-tools
     "{\"type\":\"response.function_call_arguments.delta\",\"item_id\":\"fc_item_1\",\"delta\":\"{\\\"q\\\":\"}")
    (ollama-buddy-remote--responses-extract-content-with-tools
     "{\"type\":\"response.function_call_arguments.delta\",\"item_id\":\"fc_item_1\",\"delta\":\"\\\"Emacs\\\"}\"}")
    (let* ((calls (ollama-buddy-remote--build-tool-calls-from-acc))
           (function (alist-get 'function (car calls))))
      (should (equal "call_1" (alist-get 'id (car calls))))
      (should (equal "lookup" (alist-get 'name function)))
      (should (equal "{\"q\":\"Emacs\"}" (alist-get 'arguments function))))))

(ert-deftest ollama-buddy-remote-test-responses-input-tool-results ()
  "Convert OpenAI tool history to Responses function-call items."
  :tags '(api provider)
  (let ((input
         (ollama-buddy-remote--responses-input-from-messages
          '(((role . "assistant")
             (content . "")
             (tool_calls . [((id . "call_1")
                             (type . "function")
                             (function . ((name . "lookup")
                                          (arguments . "{}"))))]))
            ((role . "tool")
             (tool_call_id . "call_1")
            (content . "result"))))))
    (should (equal "function_call" (alist-get 'type (aref input 0))))
    (should (equal "call_1" (alist-get 'call_id (aref input 0))))
    (should (equal "function_call_output" (alist-get 'type (aref input 1))))
    (should (equal "result" (alist-get 'output (aref input 1))))))

(provide 'ollama-buddy-remote-test)
;;; ollama-buddy-remote-test.el ends here
