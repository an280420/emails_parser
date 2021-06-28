require 'rubygems'
require 'bundler/setup'

Bundler.require(:default)

File.open("./temp.json","w") { |f| f.puts "[]" }

emails = []
100.times do
  emails << Faker::Internet.email(domain: 'mail.ru')
end

class Account 
  attr_accessor :email, :status, :auth_two_factor, :phone
  
  def initialize(email)
    @email = email
    @status = false
    @auth_two_factor = false
    @phone = ""
  end
end

accounts = emails.map { |email| Account.new(email)}

def check_account!(account)
  driver = Selenium::WebDriver.for :firefox
  wait = Selenium::WebDriver::Wait.new(timeout: 10)
  driver.navigate.to "https://account.mail.ru/login?page=https%3A%2F%2Faccount.mail.ru%2F%3F&"
  
  # работа с формой ввода логина
  # wait.until{ driver.find_element(:tag_name, 'h2.base-1-1-1').text == 'Войти в аккаунт'}
  # form = driver.find_element(:tag_name, 'div.login-panel')
  wait.until{ driver.find_element(xpath:  "//input[@placeholder='Имя аккаунта']") }
  account_field = driver.find_element(xpath:  "//input[@placeholder='Имя аккаунта']")
  account_field.send_keys account.email.split('@')[0]
  element_button = driver.find_element(xpath: "//span[text()='Ввести пароль']")
  element_button.click
  
  begin
    wait.until{ driver.find_element(xpath: "//small[text()='Такой аккаунт не зарегистрирован']") }
    puts "#{account.email} не зарегистирован"
    account.status = "аккаунт не зарегистрирован"
  rescue
    puts "аккаунт #{account.email} существует"
    # работа с формой ввода пароля
    wait.until{ driver.find_element(xpath: "//h2[text()='Введите пароль']")}
    password_field = driver.find_element(xpath: "//input[@placeholder='Пароль']")
    password_field.send_keys "1"
    element_button = driver.find_element(xpath: "//span[text()='Войти']")
    element_button.click
    
    # подтверждение действий
    begin
      wait.until{ driver.find_element(xpath: "//h2[text()='Хотим убедиться, что это вы']") }
      confirm_user = driver.find_element(:tag_name, 'div.login-panel')
      it_is_i_button = confirm_user.find_element(xpath: "//span[text()='Это я']")
      it_is_i_button.click
    rescue
      puts "к аккаунту #{account.email} не привязан телефон"
    end
    
    # спарсим номер телефона, если он есть
    wait.until{ driver.find_element(xpath: "//h2[text()='Введите пароль']") }
    account.status = "аккаунт существует"
    access_recovery = driver.find_element(:tag_name, 'div.login-panel')
    begin
      phone_field = access_recovery.find_element(xpath: "//a[starts-with(text(), 'По номеру телефона')]").text
      account.phone = phone_field.sub(/^По номеру телефона /, "")
      account.auth_two_factor = true
    rescue
      account.phone = 'телефон не найден'
    end
  end
  
  driver.quit
  
  # подготовим хеш для добавления в json файл
  account_hash = {
    account.email => {
      status: account.status,
      auth2factor: account.auth_two_factor,
      phone: account.phone
      }
    }

  json = File.read('./temp.json')

  File.open("./temp.json","w") do |f|
    f.puts JSON.pretty_generate(JSON.parse(json) << account_hash)
  end 
end

accounts.map { |account| check_account!(account) }
