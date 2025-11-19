ExUnit.start()

test_helpers_path = Path.join([__DIR__, "support", "test_helper.ex"])

Code.require_file(test_helpers_path)
