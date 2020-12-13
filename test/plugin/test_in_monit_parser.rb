require "helper"
require "fluent/plugin/in_monit_pull.rb"

require 'ostruct'

class HttpPullInputTestBasic < Test::Unit::TestCase
  @stub_server = nil

  setup do
    @stub_server = StubServer.new
    @stub_server.start
  end

  teardown do
    @stub_server.shutdown
  end

  TEST_CONFIG = %[
    tag test
    url http://localhost:3939/

    interval 1s
  ]

  test "parse it correctly" do
    print("Hello world!")
    d = create_driver TEST_CONFIG
    d.run(timeout: 5) do
        sleep 2
    end
    print(d.events)
  end

  def create_driver(conf)
    Fluent::Test::Driver::Input.new(Fluent::Plugin::HttpPullInput).configure(conf)
  end
end