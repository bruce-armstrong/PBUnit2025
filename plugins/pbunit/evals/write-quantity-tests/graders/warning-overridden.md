---
type: regex
target: trace
# Only in text the agent wrote (Write/Edit); the class under test's own of_Warn appears in what it reads.
pattern: '"name":"(?:Write|Edit|MultiEdit)","input":\{"file_path":"[^"]*","(?:content|old_string":"(?:[^"\\]|\\.)*","new_string)":"(?:[^"\\]|\\.)*?subroutine of_warn \(string \w+\);'
flags: i
---
