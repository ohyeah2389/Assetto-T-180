local Resistor = class("Resistor")


function Resistor:initialize(params)
    self.resistance = params.resistance
    self.amperage = 0
    self.voltage = 0
end


function Resistor:getConductance()
    return 1 / self.resistance
end


function Resistor:getCurrentContribution()
    return 0  -- Resistors don't contribute current sources
end


function Resistor:update(voltageDiff, dt)
    self.voltage = voltageDiff
    self.amperage = voltageDiff / self.resistance
end


return Resistor 