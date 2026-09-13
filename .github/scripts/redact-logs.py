import os
import re
import sys
from urllib.parse import quote

text = sys.stdin.read()
for name in ("POSTGRES_PASSWORD", "MONGODB_PASSWORD"):
    value = os.environ.get(name)
    if value:
        text = text.replace(value, "[REDACTED]").replace(
            quote(value, safe=""), "[REDACTED]"
        )
text = re.sub(r"mongodb(?:\+srv)?://[^\s]+", "mongodb://[REDACTED]", text)
sys.stdout.write(text)
