require "rubygems"
$: << File.join(File.dirname(__FILE__), "..")
$: << File.join(File.dirname(__FILE__), "..", "..", "test")
require "logstash/namespace"

class LogStash::Runner
  def main(args)
    $: << File.join(File.dirname(__FILE__), "../")

    @runners = []
    while !args.empty?
      #p :args => args
      args = run(args)
    end

    status = []
    @runners.each { |r| status << r.wait }

    # Avoid running test/unit's at_exit crap
    java.lang.System.exit(status.first)
  end # def self.main

  def run(args)
    command = args.shift
    commands = {
      "agent" => lambda do
        require "logstash/agent"
        agent = LogStash::Agent.new
        @runners << agent

        # TODO(sissel): There's a race condition somewhere that when two agents
        # run in the same process, if their startups coincide, there's some 
        # bleeding that happens between the config parsing. I haven't figured
        # out where that is yet, but this sleep helps.
        sleep 1
        return agent.run(args)
      end,
      "web" => lambda do
        require "logstash/web/runner"
        web = LogStash::Web::Runner.new
        @runners << web
        return web.run(args)
      end,
      "test" => lambda do
        require "logstash/test"
        test = LogStash::Test.new
        @runners << test
        return test.run(args)
      end
    } # commands

    if commands.include?(command)
      args = commands[command].call
    else
      if command.nil?
        $stderr.puts "No command given"
      else
        $stderr.puts "No such command #{command.inspect}"
      end
      $stderr.puts "Available commands:"
      $stderr.puts commands.keys.map { |s| "  #{s}" }.join("\n")
      exit 1
    end

    return args
  end # def run
end # class LogStash::Runner

if $0 == __FILE__
  LogStash::Runner.new.main(ARGV)
end
