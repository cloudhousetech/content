# pip3 install upguard
import upguard

api_key = "1234"
sec_key = "5678"
instance = "https://you.upguard.com"

o = upguard.Account(instance, api_key, sec_key)

env = o.environment_by_name("Production")

print("EnvironmentID:" + str(env.id))
