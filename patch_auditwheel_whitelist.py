from os.path import join, dirname, abspath
import json

from auditwheel import policy

policies = None

with open(join(dirname(abspath(policy.__file__)), "policy.json")) as f:
    policies = json.load(f)

for p in policies:
    if p["name"] == "manylinux2014":
        p["lib_whitelist"].append("libxcb.so.1")

with open(join(dirname(abspath(policy.__file__)), "policy.json"), "w") as f:
    f.write(json.dumps(policies))
