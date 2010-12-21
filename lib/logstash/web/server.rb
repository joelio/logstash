#!/usr/bin/env ruby
##rackup -Ilib:../lib -s thin

$:.unshift("%s/../lib" % File.dirname(__FILE__))
$:.unshift(File.dirname(__FILE__))

require "rubygems"
require "json"
require "eventmachine"
require "rack"
require "sinatra/async"
require "lib/elasticsearch"
require "logstash/namespace"
require "logstash/logging"
require "ap"
require "ap/mixin/action_view"

class EventMachine::ConnectionError < RuntimeError; end

class LogStash::Web::Server < Sinatra::Base
  register Sinatra::Async
  set :haml, :format => :html5
  set :logging, true
  set :public, "#{File.dirname(__FILE__)}/public"
  set :views, "#{File.dirname(__FILE__)}/views"
  elasticsearch = LogStash::Web::ElasticSearch.new

  include AwesomePrintActionView
  def h(str)
    return str
  end

  def content_tag(tag, text, options)
    return "<" + tag + ">" + text
  end


  aget '/style.css' do
    headers "Content-Type" => "text/css; charset=utf8"
    body sass :style
  end

  aget '/' do
    redirect "/search"
  end # '/'

  aget '/search' do
    @logger ||= LogStash::Logger.new(STDOUT)
    headers({"Content-Type" => "text/html" })
    if params[:q] and params[:q] != ""
      # A 'VS' query should do a query where 'VS' becomes 'OR'
      # But each facet requested should be unique.
      # This will allow us to sanely paginate VS results.
      queries = params[:q].split(" VS ")
      @results = {}

      queries.each do |query|
        p = params.clone
        p[:q] = query
        elasticsearch.search(p) do |results|
          @results[query] = (results["hits"]["hits"] rescue [])

          if @results.length == queries.length
            body haml :"search/results", :layout => !request.xhr?
          end
        end
      end
    else
      @results = {}
      body haml :"search/results", :layout => !request.xhr?
    end
  end

  apost '/search/ajax' do
    @logger ||= LogStash::Logger.new(STDOUT)

    headers({"Content-Type" => "text/html" })
    count = params["count"] = (params["count"] or 50).to_i
    offset = params["offset"] = (params["offset"] or 0).to_i

    queries = params[:q].split(" VS ")
    @results = {}
    @logger.info(["Queries", queries])
    queries.each do |query|
      p = params.clone
      p[:q] = query
      elasticsearch.search(params) do |results|
        if results.include?("error")
          body haml :"search/error", :layout => !request.xhr?
          next
        end
        @results[query] = {
          :hits => (results["hits"]["hits"] rescue []),
          :total => (results["hits"]["total"] rescue 0),
          :graphpoints => []
        }
        begin
          results["facets"]["by_hour"]["entries"].each do |entry|
            @results[query][:graphpoint] << [entry["key"], entry["count"]]
          end
        rescue => e
          puts e
        end

        if queries.length == @results.length
          # Got answers to all our queries, send the result to the client.
          if queries.length > 1
            if count and offset
              if @total > (count + offset)
                @result_end = (count + offset)
              else 
                @result_end = @total
              end
              @result_start = offset
            end # if count and offset

            if count + offset < @total
              next_params = params.clone
              next_params["offset"] = [offset + count, @total - count].min
              @next_href = "?" +  next_params.collect { |k,v| [URI.escape(k.to_s), URI.escape(v.to_s)].join("=") }.join("&")
              last_params = next_params.clone
              last_params["offset"] = @total - offset
              @last_href = "?" +  last_params.collect { |k,v| [URI.escape(k.to_s), URI.escape(v.to_s)].join("=") }.join("&")
            end # if count + offset < @total

            if offset > 0
              prev_params = params.clone
              prev_params["offset"] = [offset - count, 0].max
              @prev_href = "?" +  prev_params.collect { |k,v| [URI.escape(k.to_s), URI.escape(v.to_s)].join("=") }.join("&")

              if prev_params["offset"] > 0
                first_params = prev_params.clone
                first_params["offset"] = 0
                @first_href = "?" +  first_params.collect { |k,v| [URI.escape(k.to_s), URI.escape(v.to_s)].join("=") }.join("&")
              end
            end # if offset > 0
          end # if queries.length > 1

          @logger.info(@results)
          body haml :"search/ajax", :layout => !request.xhr?
        else
          # Notify (somehow) that a query is incomplete and waiting?
        end
      end # elasticsearch.search
    end # queries.each
  end # apost '/search/ajax'

end # class LogStashWeb

Rack::Handler::Thin.run(
  Rack::CommonLogger.new( \
    Rack::ShowExceptions.new( \
      LogStash::Web::Server.new)),
  :Port => 9292)
