# pip3 install upguard
import upguard

api_key = "1234"
sec_key = "5678"
instance = "https://you.upguard.com"

o = upguard.Account(instance, api_key, sec_key)

es = o.environments()

for e in es:
    print("id:" + str(e.id) + "\tname:" + str(e.name))
