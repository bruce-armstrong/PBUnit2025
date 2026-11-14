---
type: regex
target: trace
# Only in text the agent wrote (Write/Edit); the skill's reference files also contain retrievestart.
pattern: '"name":"(?:Write|Edit|MultiEdit)","input":\{"file_path":"[^"]*","(?:content|old_string":"(?:[^"\\]|\\.)*","new_string)":"(?:[^"\\]|\\.)*?event retrievestart'
flags: i
---
