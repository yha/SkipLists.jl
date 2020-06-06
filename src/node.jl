#================================================

Primary code for the implementation of SkiplistNode

=================================================#

using Base.Threads

#===========================
Constructors
===========================#

SkiplistNode{M}(val :: T; kws...) where {T,M} =
    SkiplistNode{T,M}(val; kws...)

SkiplistNode{M}(val :: T, height; kws...) where {T,M} =
    SkiplistNode{T,M}(val, height; kws...)

SkiplistNode{T,M}(val; p = DEFAULT_P, max_height = DEFAULT_MAX_HEIGHT, kws...) where {T,M} =
    SkiplistNode{T,M}(val, random_height(p; max_height=max_height); kws...)

function SkiplistNode{T,M}(val, height; flags = 0x0, max_height = DEFAULT_MAX_HEIGHT) where {T,M}
    height = min(height, max_height)
    next = Vector{SkiplistNode{T}}(undef, height)
    lock = ReentrantLock()

    SkiplistNode{T,M}(val, next, false, false, flags, lock)
end

LeftSentinel{T,M}(; max_height = DEFAULT_MAX_HEIGHT, kws...) where {T,M} =
    SkiplistNode{T,M}(zero(T), max_height; flags = FLAG_IS_LEFT_SENTINEL, kws...)
RightSentinel{T,M}(; max_height = DEFAULT_MAX_HEIGHT, kws...) where {T,M} =
    SkiplistNode{T,M}(zero(T), max_height; flags = FLAG_IS_RIGHT_SENTINEL, kws...)

#===========================
External API
===========================#

@inline height(node :: SkiplistNode) = length(node.next)
@inline key(node :: SkiplistNode) = node.val
@inline key(val) = val

@inline is_marked_for_deletion(node) = node.marked_for_deletion
@inline is_fully_linked(node) = node.fully_linked

@inline mark_for_deletion!(node) = (node.marked_for_deletion = true)
@inline mark_fully_linked!(node) = (node.fully_linked = true)

Base.string(node :: SkiplistNode) =
    "SkiplistNode($(key(node)), height = $(height(node)))"
Base.show(node :: SkiplistNode) = println(string(node))
Base.display(node :: SkiplistNode) = println(string(node))

"""
Check that a `SkiplistNode` is okay to be deleted, meaning that
- it's fully linked,
- unmarked, and
- that it was found at its top layer.
"""
function ok_to_delete(node, level_found)
    height(node) == level_found &&
    is_fully_linked(node) &&
    !is_marked_for_deletion(node)
end

# Node comparison

Base.:(<)(node :: SkiplistNode, val) = !(val ≤ node)
Base.:(<)(val, node :: SkiplistNode) = !(node ≤ val)
Base.:(<)(node_1 :: SkiplistNode, node_2 :: SkiplistNode) = !(node_2 ≤ node_1)

Base.:(<=)(node :: SkiplistNode, val) =
    is_sentinel(node) ? is_left_sentinel(node) : (key(node) ≤ val)

Base.:(<=)(val, node :: SkiplistNode) =
    is_sentinel(node) ? is_right_sentinel(node) : (val ≤ key(node))

function Base.:(<=)(node_1 :: SkiplistNode, node_2 :: SkiplistNode)
    if is_sentinel(node_1)
        is_left_sentinel(node_1) || is_right_sentinel(node_2)
    elseif is_sentinel(node_2)
        is_right_sentinel(node_2)
    else
        key(node_1) ≤ key(node_2)
    end
end

Base.:(==)(node :: SkiplistNode, val) = is_sentinel(node) ? false : key(node) == val
Base.:(==)(val, node :: SkiplistNode) = (node == val)
Base.:(==)(node_1 :: SkiplistNode, node_2 :: SkiplistNode) = (node_1 === node_2)

# Node links

function link_nodes!(src, dst, level)
    src.next[level] = dst
end

next(src :: SkiplistNode, level) = src.next[level]

# Flags

@inline has_flag(node, flag) = (node.flags & flag) != 0
@inline is_left_sentinel(node) = has_flag(node, FLAG_IS_LEFT_SENTINEL)
@inline is_right_sentinel(node) = has_flag(node, FLAG_IS_RIGHT_SENTINEL)
@inline is_sentinel(node) = has_flag(node, IS_SENTINEL)

#===========================
Helper functions
===========================#

"""
    random_height(p, args...)

Samples a number from a geometric distribution with parameter ``p`` and uses it
for the height of a new node in a Skiplist.

# Arguments

# Examples
"""
function random_height(p, args...; max_height = DEFAULT_MAX_HEIGHT)
    # This function uses the fact that the c.d.f. of a geometric distribution
    # is 1 - (1 - p)^k. To generate the height for a new node in a skip list,
    # we want it to be distributed as a geometric RV plus one.
    #
    # To perform this sampling, we randomly sample X ∈ [0,1], and find the
    # smallest value of k for which cdf(k) > X. We observe that
    #
    #           1 - (1 - p)^k   ≥    X                          =>
    #           (1 - p)^k       ≤    1 - X                      =>
    #           k log(1 - p)    ≤    log(1 - X)                 =>
    #           k               ≥    log(1 - X) / log(1 - p)
    #
    # (The inequality is flipped in the last step since log(1 - p) is necessarily
    # negative.) We can simplify this further by observing that Y = 1 - X has
    # the same distribution as X (i.e., Uniform([0,1])). As a result, to sample
    # a new random number, all we need to do is find the smallest integer k
    # satisfying k ≥ log(Y) / log(1 - p) for some Y ~ Uniform([0,1]), which
    # implies that
    #
    #           k = ⌈log(Y) / log(1 - p)⌉
    #

    p_scaler = 1 / log(1 - p)
    Y = rand(args...)
    @.(ceil(Int64, log(Y) * p_scaler) |> x -> min(max_height, x))
end


