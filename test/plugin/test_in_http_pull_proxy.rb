require "helper"
require "fluent/plugin/in_monit_pull.rb"

require 'ostruct'

class HttpPullInputTestProxy < Test::Unit::TestCase
  @stub_server = nil

  setup do
    @stub_server = StubServer.new
    @stub_server.start
  end

  teardown do
    @stub_server.shutdown
  end

  sub_test_case "success case behind proxy" do
    TEST_INTERVAL_3_PROXY_CONFIG = %[
      tag test
      url http://localhost:3939
      proxy http://localhost:4040

      interval 3s
      format none
    ]

    TEST_INTERVAL_3_REDIRECT_PROXY_CONFIG = %[
      tag test
      url http://localhost:3939/redirect
      proxy http://localhost:4040

      interval 3s
      format json
    ]

    TEST_AUTH_SUCCESS_PROXY_CONFIG = %[
      tag test
      url http://localhost:3939/protected
      proxy http://localhost:4040
      timeout 2s
      user HatsuneMiku
      password 3939

      interval 3s
      format json
    ]

    setup do
      @proxy_server = StubProxy.new
      @proxy_server.start
    end

    teardown do
      @proxy_server.shutdown
    end

    test 'interval 3 with redirect' do
      d = create_driver TEST_INTERVAL_3_REDIRECT_PROXY_CONFIG
      assert_equal("test", d.instance.tag)
      assert_equal(3, d.instance.interval)

      d.run(timeout: 8) do
        sleep 7
      end
      assert_equal(2, d.events.size)

      d.events.each do |tag, time, record|
        assert_equal("test", tag)

        assert_equal({"url"=>"http://localhost:3939/redirect","status"=>200, "message"=>{"status"=>"OK"}}, record)
        assert(time.is_a?(Fluent::EventTime))
      end
    end

    test 'interval 3 with corrent password' do
      d = create_driver TEST_AUTH_SUCCESS_PROXY_CONFIG
      assert_equal("test", d.instance.tag)
      assert_equal(3, d.instance.interval)

      d.run(timeout: 8) do
        sleep 7
      end
      assert_equal(2, d.events.size)

      d.events.each do |tag, time, record|
        assert_equal("test", tag)

        assert_equal({"url"=>"http://localhost:3939/protected","status"=>200, "message"=>{"status"=>"OK"}}, record)
        assert(time.is_a?(Fluent::EventTime))
      end
    end
  end

  private

  def create_driver(conf)
    Fluent::Test::Driver::Input.new(Fluent::Plugin::HttpPullInput).configure(conf)
  end
end
