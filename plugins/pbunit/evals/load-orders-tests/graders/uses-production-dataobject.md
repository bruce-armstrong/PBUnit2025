---
type: regex
target: trace
# Only in text the agent wrote (Write/Edit).
pattern: '"name":"(?:Write|Edit|MultiEdit)","input":\{"file_path":"[^"]*","(?:content|old_string":"(?:[^"\\]|\\.)*","new_string)":"(?:[^"\\]|\\.)*?DataObject\s*=\s*\\"d_orders\\"'
flags: i
---
