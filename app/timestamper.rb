require 'sinatra/base'
require 'thin'
require 'json'
require 'cassandra'
require './icons'
require 'byebug'

module Errors
  class NoDBException < StandardError; end
end

class CassandraDB
  def session
    @_session unless @_session.nil?

    establish_connection(ENV['CASSANDRA_PORT_9042_TCP_ADDR']) unless ENV['CASSANDRA_PORT_9042_TCP_ADDR'].nil?
    establish_connection('cassandra') unless ENV['KUBERNETES_RO_PORT'].nil?

    @_session
  end

  def establish_connection(cassandra_ip)
    # cassandra_ip = ENV['CASSANDRA_PORT_9042_TCP_ADDR']
    @cluster = Cassandra.cluster(hosts: cassandra_ip, connect_timeout: 5) if @cluster.nil?

    keyspace_definition = <<-KEYSPACE_CQL
      CREATE KEYSPACE IF NOT EXISTS timestamps_repo
      WITH replication = {
        'class': 'SimpleStrategy',
        'replication_factor': 3
      }
    KEYSPACE_CQL

    @_session = @cluster.connect

    @_session.execute(keyspace_definition)
    @_session.execute('USE timestamps_repo')

    table_definition = <<-TABLE_CQL
      CREATE TABLE IF NOT EXISTS timestamps_table (
        id timeuuid,
        icon VARCHAR,
        ts timestamp,
        PRIMARY KEY (id)
      );
    TABLE_CQL
    @_session.execute(table_definition)
  end

  def disconnect!
  end
end

class TimeStamperApp < Sinatra::Base

  def initialize
    super()
    @cdb = CassandraDB.new
  end

  before do
  end

  after do
    # @cdb.session.close
  end

  get '/' do
    locals_hash = nil
    bad_times = false
    all_timestamps = []

    begin
      all_timestamps = getAllTimeStamps
      locals_hash = generate_content
    rescue Exception => e
      puts e
      bad_times = true
    end

    erb :index, :locals => locals_hash.merge(:all_timestamps => all_timestamps)
  end

  get '/json' do
    puts "received json and responding"
    response_value = generate_content
    puts response_value
    content_type :json
      response_value.to_json
  end

  get '/_status/healthz' do
    "OK"
  end

  def generate_content
    bad_times = false
    current_timestamp = nil
    current_icon = nil
    ser_ver = nil

    begin
      puts params
      raise Errors::NoDBException if params[:fail] == 'true'
      current_timestamp = Time.now.iso8601
      current_icon = AllIcons.getRand
      ser_ver = recordTimeStamp(current_timestamp, current_icon)
    rescue Exception => e
      puts e
      bad_times = true
    end

      {
        :bad_times => bad_times,
        :timestamp => current_timestamp,
        :icon => current_icon,
        :ser_ver => ser_ver      
      }
  end

  def getAllTimeStamps
    future = @cdb.session.execute_async("select * from timestamps_table", timeout: 5)
    rows = future.get()
    ser_ver = rows.execution_info.hosts.first.release_version
    rows.sort{ |a, b| a["ts"] <=> b["ts"] }.reverse.map{|row| row.merge({:ser_ver => ser_ver})}
    # .execution_info.hosts.last.release_version
  end

  def recordTimeStamp(current_timestamp, current_icon)
    future = @cdb.session.execute_async("INSERT INTO timestamps_table(id, icon, ts) VALUES (now(), '#{current_icon}', '#{current_timestamp}')", timeout: 1)
    row = future.get() 
    row.execution_info.hosts.first.release_version
  end
end
