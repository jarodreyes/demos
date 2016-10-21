require "bundler/setup"
require "sinatra"
require "sinatra/multi_route"
require "twilio-ruby"
require 'twilio-ruby/rest/messages'
require "sanitize"
require "erb"
require "rotp"
require "haml"
require "net/http"
require "uri"
include ERB::Util

set :static, true
set :root, File.dirname(__FILE__)

before do
  @twilio_number = ENV['TWILIO_NUMBER']
  @points_number = ENV['POINTS_NUMBER']
  @mms_number = ENV['INVISIBLE_NUMBER']
  @client = Twilio::REST::Client.new ENV['TWILIO_ACCOUNT_SID'], ENV['TWILIO_AUTH_TOKEN'], :host => 'api-twilio-com-cgxfsyzjzffz.runscope.net'
end

get "/" do
  haml :index
end

# http://mmsdemo.herokuapp.com/branded-sms
# Branded SMS Webhook, first asks for device, then sends MMS
route :get, :post, '/branded-sms' do
  @client = Twilio::REST::Client.new ENV['TWILIO_ACCOUNT_SID'], ENV['TWILIO_AUTH_TOKEN']
  $DEVICES = {
    "iphone" => {
      "url" => 'https://s3-us-west-2.amazonaws.com/deved/branded-sms_ios7.png',
    },
    "android" => {
      "url" => 'https://s3-us-west-2.amazonaws.com/deved/branded-sms_android.png',
    },
    "windows" => {
      "url" => 'https://s3-us-west-2.amazonaws.com/deved/branded-sms_windows.png',
    }
  }
  @phone_number = Sanitize.clean(params[:From])
  @body = params[:Body].downcase
  deviceList = ($DEVICES.keys).join(',')
  if deviceList.include?(@body)
    pic = $DEVICES[@body]['url']
    puts pic
    message = @client.account.messages.create(
      :from => 9792726399,
      :to => @phone_number,
      :media_url => pic,
    )
    puts message.to
  else
    @msg = "What kind of device do you have? Reply: 'iphone', 'android', or 'windows' to receive a branded SMS"
    message = @client.account.messages.create(
      :from => 9792726399,
      :to => @phone_number,
      :body => @msg
    )
    puts message.to
  end
  halt 200
end

route :get, :post, '/points' do

  if params[:phone_number].nil?
    @phone_number = Sanitize.clean(params[:From])
  else
    @phone_number = Sanitize.clean(params[:phone_number])
  end
  @msg = "Travel Deal Alert: JFK-LAX: $32 One-way. 2475 Miles on JetBlue. You're welcome. -TPG"
  @media = "https://s3-us-west-1.amazonaws.com/jardiohead/branded-tpglg.png"
  message = @client.account.messages.create(
    :from => @points_number,
    :to => @phone_number,
    :media_url => @media,
  )
  puts message.to
  sleep(20)
  message2 = @client.account.messages.create(
    :from => @points_number,
    :to => @phone_number,
    :body => @msg,
  )
  puts message2.to
  halt 200
end

# Generic webhook to send sms from 'TWILIO'
get '/mms-demo' do
  @body = params[:Body].downcase
  if @body.include? "croll"
    @media = "https://s3-us-west-1.amazonaws.com/jardiohead/scrolling.gif"
  elsif @body.include? "brand"
    @media = "https://s3-us-west-1.amazonaws.com/jardiohead/branded-tpglg.png"
  else
    @media = "https://s3-us-west-1.amazonaws.com/jardiohead/invisiblesms.gif"
  end
  @phone_number = Sanitize.clean(params[:From])
  message = @client.account.messages.create(
    :from => @mms_number,
    :to => @phone_number,
    :media_url => @media,
  )
  puts message.to
  halt 200
end

# Generic webhook to send sms from 'TWILIO'
post '/robot_eyes' do
  body = params[:Body]

  access_token = ENV['PARTICLE_ACCESS_TOKEN']
  uri = URI.parse("https://api.particle.io/v1/devices/28001e000547353138383138/text")

  # Shortcut
  robotReq = Net::HTTP.post_form(uri, {"access_token" => access_token, "args" => body})
  p robotReq
  response = Twilio::TwiML::Response.new do |r|
    r.Sms "🤖 Thank you for texting my robot face! <3 Elliott Bot 3000! 🤖"
  end
  response.text
end
