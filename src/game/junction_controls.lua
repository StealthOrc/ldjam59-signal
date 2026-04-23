local junctionControls = {}

local COUPLED_OUTPUT_CONTROL_TYPES = {
    relay = true,
    crossbar = true,
}

local function getOutputCount(junction)
    if type(junction) ~= "table" then
        return 0
    end

    local explicitCount = tonumber(junction.outputCount)
    if explicitCount then
        return explicitCount
    end

    if type(junction.outputs) == "table" then
        return #junction.outputs
    end

    if type(junction.outputEdgeIds) == "table" then
        return #junction.outputEdgeIds
    end

    if type(junction.outputEndpointIds) == "table" then
        return #junction.outputEndpointIds
    end

    return 0
end

function junctionControls.getControlType(junction)
    if type(junction) ~= "table" then
        return nil
    end

    if type(junction.controlType) == "string" then
        return junction.controlType
    end

    if type(junction.control) == "table" then
        return junction.control.type
    end

    return nil
end

function junctionControls.isOutputCoupledToMainControl(junctionOrControlType)
    local controlType = junctionOrControlType
    if type(junctionOrControlType) == "table" then
        controlType = junctionControls.getControlType(junctionOrControlType)
    end

    return COUPLED_OUTPUT_CONTROL_TYPES[controlType] == true
end

function junctionControls.hasManualOutputSelector(junction)
    return getOutputCount(junction) > 1
        and not junctionControls.isOutputCoupledToMainControl(junction)
end

return junctionControls
