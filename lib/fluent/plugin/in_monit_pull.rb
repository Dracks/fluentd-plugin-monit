#
# Copyright 2017- filepang
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

require "fluent/plugin/input"
require "rest-client"
require 'rexml/document'

TRANSFORMATION = {
  "5" => { # global system information
    "load-avg-1": "system/load/avg01",
    "load-avg-5": "system/load/avg05",
    "load-avg-15": "system/load/avg15",
    "cpu-user": "system/cpu/user",
    "cpu-system": "system/cpu/system",
    "cpu-wait": "system/cpu/wait",
    "memory-percent": "system/memory/percent",
    "memory-kb": "system/memory/kilobyte",
    "swap-percent": "system/swap/percent",
    "swap-kb": "system/swap/kilobyte",
    "index": "global",
  },
  "0" => { # Hard disk
    "usage": "block/percent",
    "index": "disk"
  },
  "3" => { # Process
    "uptime": "uptime",
    "memory-percent": "memory/percent",
    "cpu-percent": "cpu/percent",
    "index": "process"
  }
}

module Fluent
  module Plugin
    class HttpPullInput < Fluent::Plugin::Input
      Fluent::Plugin.register_input("monit_pull", self)
      helpers :timer, :compat_parameters

      def initialize
        super
      end

      # basic options
      desc 'The tag of the event.'
      config_param :tag, :string

      desc 'The url of monitoring target'
      config_param :url, :string

      desc 'The interval time between periodic request'
      config_param :interval, :time

      desc 'The user agent string of request'
      config_param :agent, :string, default: "fluent-plugin-http-pull"

      desc 'The http method for each request'
      config_param :http_method, :enum, list: [:get, :post, :delete], default: :get

      desc 'The timeout second of each request'
      config_param :timeout, :time, default: 10

      # proxy options
      desc 'The HTTP proxy URL to use for each requests'
      config_param :proxy, :string, default: nil

      # basic auth options
      desc 'user of basic auth'
      config_param :user, :string, default: nil

      desc 'password of basic auth'
      config_param :password, :string, default: nil, secret: true

      # ssl options
      desc 'verify_ssl'
      config_param :verify_ssl, :bool, default: true

      desc "The absolute path of directory where ca_file stored"
      config_param :ca_path, :string, default: nil

      desc "The absolute path of ca_file"
      config_param :ca_file, :string, default: nil


      def configure(conf)
        super

        @_request_headers = {
          "Content-Type" => "application/x-www-form-urlencoded",
          "User-Agent" => @agent
        }

        @http_method = :get
      end

      def start
        super

        timer_execute(:in_monit_pull, @interval, &method(:on_timer))
      end

      def on_timer
        body = nil
        record = nil

        begin
          res = RestClient::Request.execute request_options
          if res.code == 200
            extract_and_emit(res.body())
            print("ping\n")
          end
        rescue StandardError => err
          print(err)
          record = { "url" => @url, "error" => err.message }
          if err.respond_to? :http_code
            record["status"] = err.http_code || 0
          else
            record["status"] = 0
          end
        end

        # router.emit(@tag, record_time, record)
      end

      def shutdown
        super
      end

      private
      def request_options
        options = { method: @http_method, url: @url, timeout: @timeout, headers: @_request_headers }

        options[:proxy] = @proxy if @proxy
        options[:user] = @user if @user
        options[:password] = @password if @password

        options[:verify_ssl] = @verify_ssl
        if @verify_ssl and @ca_path and @ca_file
          options[:ssl_ca_path] = @ca_path
          options[:ssl_ca_file] = @ca_file
        end

        return options
      end

      def extract_and_emit(body)
        time = Engine.now
        doc = REXML::Document.new(body)
        services = doc.elements["/monit/services"]
        services.elements.each { |service|
          type = service.elements["type"].text
          if TRANSFORMATION.has_key? type
            process_service(TRANSFORMATION[type], service, time)
          end
        }
      end

      def process_service(map, service, time)
        name = service.attributes["name"]

        record = {
          "name": name
        }
        map.each { |key, path|
          if key != "index"
            field = service.elements[path]
            if field
              record[key] = field.text
            else
              print("Error on",path,"\n")
            end
          end
        }
        router.emit(@tag+"."+map["index"], time, record)
      end
    end
  end
end
