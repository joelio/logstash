require "logstash/inputs/base"
require "logstash/namespace"

# Read events from an email account. Currently only supports IMAPS (SSL)
#
class LogStash::Inputs::Imap < LogStash::Inputs::Base

  config_name "imap"

  # The hostname of your IMAP server.
  config :host, :validate => :string, :required => true

  # The port to connect to. Defaults to TCP 993.
  config :port, :validate => :number, :default => 993 

  # The user to connect as.
  config :username, :validate => :string, :required => true

  # Password to authenticate with. 
  config :password, :validate => :string, :required => true
  
  # IMAP folder to open. Defaults to "INBOX".
  config :folder, :validate => :string, :default => "INBOX"

  # Refresh interval (in seconds). Defaults to 60.
  config :refresh, :validate => :number, :default => 60

  # Initial connection timeout (in seconds).
  config :timeout, :validate => :number, :default => 5


  public
  def register
    require 'net/imap'
    @connection = Net::IMAP.new(@host, @port ,true)
    @connection.login(@username,@password)
    @connection.select('INBOX')
  end # def register


  public
  def run(queue)
    loop do
      @connection.search(["ALL"]).each do |message_id|
        e = @connection.fetch(message_id, ["ENVELOPE","UID","BODY","BODY[TEXT]"])
        if e
          queue << e
        end
      end
      sleep @refresh
    end # loop
  end # def run


  public
  def teardown
    @connection.logout()
    @connection.disconnect()
  end

end # class LogStash::Inputs::Imap
