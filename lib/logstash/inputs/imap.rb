require "logstash/inputs/base"
require "logstash/namespace"

# Read events from an IMAP mailbox 
#
# TODO (joelio): Add some options to delete and expunge / Add IMAP IDLE?
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
  config :folder, :validate => :string, :default => 'INBOX'

  # Refresh interval (in seconds). Defaults to 0.
  config :refresh, :validate => :number, :default => 0

  # Initial connection timeout (in seconds).
  config :timeout, :validate => :number, :default => 5


  public
  def register
    require 'net/imap'
    @connection = Net::IMAP.new(@host, @port ,true)
    @connection.login(@username,@password)
    @connection.select(@folder)
  end # def register


  public
  def run(queue)
    loop do
      @connection.search(["NOT", "SEEN"]).each do |message_id|
        e = @connection.fetch(message_id, ["ENVELOPE","UID","BODY","BODY[TEXT]"])
        if e
          queue << e
          @connection.store(message_id, "+FLAGS", [:Seen])
        end
      end 
      sleep @refresh
    end # loop
  end # def run


  public
  def teardown
    @connection.logout()
    @connection.disconnect()
  end # def teardown

end # class LogStash::Inputs::Imap
