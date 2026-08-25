run "file_creation" {
  command = apply

  module {
    source = "./."
  }

  variables {
    filename = "test-hello.txt"
    content  = "Terraform testing works!"
  }

  assert {
    condition     = output.filename == "${path.root}/test-hello.txt"
    error_message = "The module did not create the expected filename."
  }
}
