---
--- Generated by EmmyLua(https://github.com/EmmyLua)
--- Created by xindong.
--- DateTime: 2021/2/24 17:56
---

require 'base.deque'
require 'base.event_deque'
require 'base.co'


env_test_dict.deque_example1 = function()
    local d = base.deque()
    assert(#d == 0)

    d:push_front(1)
    assert(#d == 1)

    d:push_front(2)
    assert(d:pop_back() == 1)

    d:push_back(3)
    d:push_back(4)
    assert(#d == 3)

    assert(d:pop_front() == 2)
    assert(d:pop_front() == 3)
    assert(d:pop_front() == 4)

    assert(#d == 0)

    local _, err = d:pop_back()
    assert(err == 'empty')
end

env_test_dict.deque_example2 = function()
    local d  ---@type deque
    d = base.deque()
    assert(d:closed() == false)
    d:push_back(1)
    d:push_back(2)
    d:push_back(3)
    d:close()
    assert(d:closed() == true)
    assert(#d == 3)
    assert(d:pop_front() == 1)
    assert(d:pop_front() == 2)
    d:pop_front(function(ret)
        assert(ret == 3)
    end)
    local _, err = d:pop_front()
    assert(err == 'closed')   -- not 'empty'

    d = base.deque()
    d:push_back(1)
    d:push_back(2)
    d:push_back(3)
    d:close(true)
    assert(#d == 0)

    d = base.deque()
    d:push_back(1)
    d:push_back(2)
    d:push_back(3)
    local sum = 0
    d:close(function(n)
        sum = sum + n
    end)
    assert(#d == 0)
    assert(sum == 6)  -- 1 + 2 + 3
end

env_test_dict.deque_example3 = function()
    local q = base.queue()
    q:push(1)
    q:push(2)
    q:push(3)
    assert(#q == 3)

    assert(q:pop() == 1)
    assert(q:pop() == 2)
    assert(q:pop() == 3)
    assert(#q == 0)
end

env_test_dict.event_deque_example1 = function()
    local d = base.event_deque()
    assert(#d == 0)

    local pro1 = coroutine.as_promise(function()
        coroutine.sleep(500)
        d:push_back(1)
        coroutine.sleep(1000)
        d:push_back(2)
        d:push_back(3)
    end)

    local ret, err = d:pop_back()  -- 不阻塞, 和deque行为一致, 立即返回结果
    assert(ret == nil and err == 'empty')

    local pro2 = coroutine.as_promise(function()
        coroutine.sleep(1000)
        local ret, err = d:pop_front()
        assert(ret == 1 and err == nil)
        coroutine.sleep(1000)
        d:pop_front(nil, function(ret)
            assert(ret == 2)
        end)

        assert(#d == 1)
    end)

    pro1:co_get()
    pro2:co_get()
end

env_test_dict.event_deque_example2 = function()
    local d = base.event_deque()

    local pro1 = coroutine.as_promise(function()
        coroutine.sleep(500)
        d:push_back(1)
    end)

    local pro2 = coroutine.as_promise(function()
        local ret, err = d:co_pop_front()
        assert(ret == 1)

        ret, err = d:co_pop_front(2000)
        assert(err == 'timeout')
    end)

    pro1:co_get()
    pro2:co_get()
end
