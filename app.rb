require "bundler/setup"
require "sinatra"
require "sinatra/multi_route"
require "twilio-ruby"
require 'twilio-ruby/rest/messages'
require "sanitize"
require "erb"
require "rotp"
require "haml"
include ERB::Util

set :static, true
set :root, File.dirname(__FILE__)

before do
  @twilio_number = ENV['TWILIO_NUMBER']
  @points_number = ENV['POINTS_NUMBER']
  @client = Twilio::REST::Client.new ENV['TWILIO_ACCOUNT_SID'], ENV['TWILIO_AUTH_TOKEN']
  puts "num: #{@twilio_number}"
  @mmsclient = @client.accounts.get(ENV['TWILIO_SID'])
  
  if params[:error].nil?
    @error = false
  else
    @error = true
  end

end

def sendMessage(from, to, body, media)
  if media.nil?
    message = @client.account.messages.create(
      :from => from,
      :to => to,
      :body => body
    )
  else
    message = @mmsclient.messages.create(
      :from => from,
      :to => to,
      :body => body,
      :media_url => media,
    )
  end
  puts message.to
end

def createUser(name, phone_number, send_mms, verified)
  user = VerifiedUser.create(
    :name => name,
    :phone_number => phone_number,
    :send_mms => send_mms,
  )
  if verified == true
    user.verified = true
    user.save
  end
  Twilio::TwiML::Response.new do |r|
    r.Message "Awesome, #{name} at #{phone_number} you have been added to the Reyes family babynotify.me account."
  end.text
end

get "/" do
  haml :index
end

get "/signup" do
  haml :signup
end

get '/gotime' do
  haml :gotime
end

get '/notify' do
  p '//////////////////// --------------------'
  p ENV['TWILIO_SID']
  p @client.accounts.get(ENV['TWILIO_SID'])
  @mmsclient.messages.create(
    :from => 'TWILIO',
    :to => '2066505813',
    :body => "Hi Jarod",
  )
end

get '/twilions' do
  haml :twilions
end

get '/success' do
  haml :success
end

get '/kindthings' do
  @messages = Message.all
  haml :messages
end

get '/users/' do
  @users = VerifiedUser.all
  haml :users
end

# http://baby-notifier.herokuapp.com/branded-sms
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

# Generic webhook to send sms from 'TWILIO'
get '/sms-hook' do
  @user = params[:to]
  if params[:msg].nil?
    @msg = 'Congrats you have just sent an SMS with just a few lines of code.'
  else
    @msg = params[:msg]
  end
  message = @mmsclient.messages.create(
    :from => 'TWILIO',
    :to => @user,
    :body => @msg,
    :media_url => "http://baby-notifier.herokuapp.com/img/sms-pic.png",
  )
  puts message.to
  halt 200
end

# Receive messages twilio app endpoint - inbound
route :get, :post, '/christmas' do
  @xmas_number = ENV['XMAS_NUMBER']
  @phone_number = Sanitize.clean(params[:From])
  @body = params[:Body]
  @message = "Congratulations and Happy Holidays! You are receiving this message because you found the #12HacksOfChristmas easter-egg. For your efforts you will be greatly rewarded this winter. If you'd like to receive your prize, simply respond with your name and mailing address."
  sendMessage @xmas_number, @phone_number, @message, nil
end

# Receive messages twilio app endpoint - inbound
route :get, :post, '/christmas-voice' do
  Twilio::TwiML::Response.new do |r|
    r.Say "Congratulations! You are receiving this message because you found the twelve hacks of christmas easter-egg. For your efforts you will be greatly rewarded this winter. If you'd like to receive your prize, please send an SMS to this number with your name and mailing address. Happy Holidays! ", loop: 2, voice: 'alice', language: 'en-GB'
  end.text
end