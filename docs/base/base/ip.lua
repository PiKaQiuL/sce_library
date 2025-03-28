---@meta _

---
--- SCE Library IP和环境相关功能
--- 提供IP地址处理和环境检测相关的功能
---

---获取本机IP地址
---@return string 本机IP地址
function get_local_ip() end

---检查当前是否为开发环境
---@return boolean 如果是开发环境则返回true，否则返回false
function is_dev_env() end

---检查当前是否为测试环境
---@return boolean 如果是测试环境则返回true，否则返回false
function is_test_env() end

---检查当前是否为生产环境
---@return boolean 如果是生产环境则返回true，否则返回false
function is_prod_env() end

---获取当前环境名称
---@return string 环境名称，可能的值包括"dev"、"test"、"prod"等
function get_env_name() end