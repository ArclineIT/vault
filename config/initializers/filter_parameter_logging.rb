# Be sure to restart your server when you modify this file.

# Keep secret values, tokens and anything like them out of the log file.
Rails.application.config.filter_parameters += [
  :passw, :email, :secret, :token, :_key, :crypt, :salt, :certificate, :otp, :ssn, :cvv, :cvc, :value
]
