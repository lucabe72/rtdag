#ifndef RTDAG_MQUEUE_H
#define RTDAG_MQUEUE_H

#include <bitset>
#include <condition_variable>
#include <mutex>
#include <vector>

#include "logging.h"
#include "newstuff/integers.h"

typedef std::vector<int *> MultiQueue;
struct Edge {
    const int from;
    const int to;
    const int push_idx;
    MultiQueue &mq;
    std::vector<u8> msg;

    template <class Value>
    Value &as_value() {
        return *(reinterpret_cast<Value *>(msg.data()));
    }

    // The last argument is to differentiate with the other constructor
    template <class Value>
    Edge(MultiQueue &mq, int from, int to, int push_idx, const Value &value,
         bool unused) :
        from(from), to(to), push_idx(push_idx), mq(mq), msg(sizeof(Value)) {

        (void)unused;

        // Assign value to the buffer pointed by the vector
        as_value<Value>() = value;
    }

    Edge(MultiQueue &mq, int from, int to, int push_idx, int msg_size) :
        from(from), to(to), push_idx(push_idx), mq(mq), msg(msg_size, '.') {

        // The message is initialized with '.' (above) and a termination
        // std::string character. This is to avoid errors when checking
        // that the transferred data is correct.
        msg[msg_size - 1] = '\0';
    }
};

#endif // RTDAG_MQUEUE_H
