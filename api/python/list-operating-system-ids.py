# pip3 install upguard
import upguard

api_key = "1234"
sec_key = "5678"
instance = "https://you.upguard.com"

o = upguard.Account(instance, api_key, sec_key)

oss = o.operating_systems()

print("os.name,os.id,osf.name,osf.id")
for os in oss:
    osf = os.operating_system_family()
    print("" + os.name + "," + str(os.id) + "," + osf.name + "," + str(osf.id)) 



