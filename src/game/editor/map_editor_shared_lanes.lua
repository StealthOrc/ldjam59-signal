return function(mapEditor, shared)
    local moduleEnvironment = setmetatable({ mapEditor = mapEditor }, {
        __index = function(_, key)
            local sharedValue = shared[key]
            if sharedValue ~= nil then
                return sharedValue
            end

            return _G[key]
        end,
        __newindex = shared,
    })

    setfenv(1, moduleEnvironment)

local function copyLanePoint(point)
    return {
        x = point.x,
        y = point.y,
    }
end

function mapEditor:clearSharedLaneIndex()
    self.sharedLanes = {}
    self.sharedLanesById = {}
    self.sharedLaneByRouteSegment = {}
end

function mapEditor:buildSharedLaneId(firstPoint, secondPoint)
    if not firstPoint or not secondPoint then
        return nil
    end

    return buildSegmentGroupKey(firstPoint, secondPoint)
end

function mapEditor:rebuildSharedLaneIndex()
    self:clearSharedLaneIndex()

    for _, route in ipairs(self.routes or {}) do
        self.sharedLaneByRouteSegment[route.id] = {}

        for segmentIndex = 1, #route.points - 1 do
            local firstPoint = route.points[segmentIndex]
            local secondPoint = route.points[segmentIndex + 1]
            local laneId = self:buildSharedLaneId(firstPoint, secondPoint)

            if laneId then
                local lane = self.sharedLanesById[laneId]
                if not lane then
                    lane = {
                        id = laneId,
                        startPoint = copyLanePoint(firstPoint),
                        endPoint = copyLanePoint(secondPoint),
                        members = {},
                        routeIds = {},
                        routeLookup = {},
                    }
                    self.sharedLanesById[laneId] = lane
                    self.sharedLanes[#self.sharedLanes + 1] = lane
                end

                lane.members[#lane.members + 1] = {
                    route = route,
                    segmentIndex = segmentIndex,
                }

                if not lane.routeLookup[route.id] then
                    lane.routeLookup[route.id] = true
                    lane.routeIds[#lane.routeIds + 1] = route.id
                end

                self.sharedLaneByRouteSegment[route.id][segmentIndex] = lane
            end
        end
    end

    for _, lane in ipairs(self.sharedLanes) do
        table.sort(lane.members, function(first, second)
            if first.route.id ~= second.route.id then
                return first.route.id < second.route.id
            end

            return first.segmentIndex < second.segmentIndex
        end)
        table.sort(lane.routeIds)
    end
end

function mapEditor:getSharedLaneForSegment(route, segmentIndex)
    if not route or not segmentIndex then
        return nil
    end

    local routeSegments = self.sharedLaneByRouteSegment and self.sharedLaneByRouteSegment[route.id] or nil
    local lane = routeSegments and routeSegments[segmentIndex] or nil
    if lane then
        return lane
    end

    self:rebuildSharedLaneIndex()
    routeSegments = self.sharedLaneByRouteSegment and self.sharedLaneByRouteSegment[route.id] or nil
    return routeSegments and routeSegments[segmentIndex] or nil
end

function mapEditor:getSharedLaneMembers(route, segmentIndex)
    local lane = self:getSharedLaneForSegment(route, segmentIndex)
    local members = {}

    if not lane then
        return members
    end

    for _, member in ipairs(lane.members or {}) do
        members[#members + 1] = {
            route = member.route,
            segmentIndex = member.segmentIndex,
        }
    end

    return members
end

function mapEditor:getSharedLaneDebugName(lane)
    if not lane then
        return "shared lane"
    end

    local routeNames = {}
    for _, routeId in ipairs(lane.routeIds or {}) do
        local route = self:getRouteById(routeId)
        routeNames[#routeNames + 1] = self:getRouteDebugName(route)
    end

    if #routeNames == 0 then
        return "shared lane"
    end

    return string.format("shared lane (%s)", table.concat(routeNames, ", "))
end

function mapEditor:restoreLinkedPointGroupsForRoutes(routeIds)
    local groups = {}
    local targetRoutes = {}

    if routeIds and #routeIds > 0 then
        for _, routeId in ipairs(routeIds) do
            local route = self:getRouteById(routeId)
            if route then
                targetRoutes[#targetRoutes + 1] = route
            end
        end
    else
        targetRoutes = self.routes or {}
    end

    for _, route in ipairs(targetRoutes) do
        for pointIndex = 2, #route.points - 1 do
            local point = route.points[pointIndex]
            local existingLinkedPointGroupId = point.linkedPointGroupId
            local previousLane = self:getSharedLaneForSegment(route, pointIndex - 1)
            local nextLane = self:getSharedLaneForSegment(route, pointIndex)
            local previousLaneId = previousLane and #(previousLane.members or {}) > 1 and previousLane.id or "-"
            local nextLaneId = nextLane and #(nextLane.members or {}) > 1 and nextLane.id or "-"

            point.linkedPointGroupId = nil

            if point.sharedPointId == nil and (previousLaneId ~= "-" or nextLaneId ~= "-") then
                local group = nil
                for _, candidateGroup in ipairs(groups) do
                    if candidateGroup.previousLaneId == previousLaneId
                        and candidateGroup.nextLaneId == nextLaneId
                        and distanceSquared(point.x, point.y, candidateGroup.x, candidateGroup.y) <= INTERSECTION_POINT_TOLERANCE_SQUARED then
                        group = candidateGroup
                        break
                    end
                end

                if not group then
                    group = {
                        x = point.x,
                        y = point.y,
                        previousLaneId = previousLaneId,
                        nextLaneId = nextLaneId,
                        members = {},
                        routeLookup = {},
                        existingLinkedPointGroupId = nil,
                    }
                    groups[#groups + 1] = group
                else
                    local memberCount = #group.members
                    group.x = (group.x * memberCount + point.x) / (memberCount + 1)
                    group.y = (group.y * memberCount + point.y) / (memberCount + 1)
                end

                group.members[#group.members + 1] = point
                group.routeLookup[route.id] = true
                if existingLinkedPointGroupId and not group.existingLinkedPointGroupId then
                    group.existingLinkedPointGroupId = existingLinkedPointGroupId
                end
            end
        end
    end

    for _, group in ipairs(groups) do
        local routeCount = 0
        for _, _ in pairs(group.routeLookup) do
            routeCount = routeCount + 1
        end

        if routeCount > 1 and #group.members > 1 then
            local linkedPointGroupId = group.existingLinkedPointGroupId or self.nextLinkedPointGroupId
            if not group.existingLinkedPointGroupId then
                self.nextLinkedPointGroupId = self.nextLinkedPointGroupId + 1
            end

            for _, point in ipairs(group.members) do
                point.linkedPointGroupId = linkedPointGroupId
            end
        end
    end
end

end
