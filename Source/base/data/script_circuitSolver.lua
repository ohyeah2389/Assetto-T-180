-- T-180 CSP Physics Script - Circuit Solver Module
-- Modified Nodal Analysis Implementation
-- Authored by ohyeah2389


local matrix = require('script_matrix')


local CircuitSolver = class("CircuitSolver")


function CircuitSolver:initialize(params)
    params = params or {}
    self.nodes = {}
    self.components = {}
    self.nextNodeId = 1
    self.groundNodeId = 1  -- Node 1 is always ground (0V)
    self.batteryPos = nil  -- Store battery positive node
    self.battery = nil     -- Store battery component
    self.debug = params.debug or false
end


function CircuitSolver:addNode(fixedVoltage)
    local nodeId = self.nextNodeId
    self.nextNodeId = self.nextNodeId + 1
    self.nodes[nodeId] = { 
        voltage = 0,
        connections = {},
        isFixed = fixedVoltage ~= nil,
        fixedVoltage = fixedVoltage or 0
    }
    return nodeId
end


function CircuitSolver:addComponent(component, nodeA, nodeB)
    local debug_output = ""
    
    -- Track battery component and its positive terminal
    if component.class and component.class.name == "Battery" then
        if self.debug then
            debug_output = debug_output .. "Found battery component, positive terminal at node " .. nodeA .. "\n"
        end
        self.battery = component
        self.batteryPos = nodeA
        -- Set initial node voltages for battery
        self.nodes[nodeA].voltage = component.voltage
        self.nodes[nodeB].voltage = 0
    end
    
    table.insert(self.components, {
        component = component,
        nodeA = nodeA,
        nodeB = nodeB,
        name = component.class and component.class.name or "unknown"  -- Store component name
    })
    
    return debug_output
end


function CircuitSolver:solve(dt)
    self.debug = {
        nodes = {},
        components = {},
        battery = {
            voltage = 0,
            current = 0,
            power = 0,
            regenComponents = {}
        }
    }

    -- Track node voltages
    for nodeId, node in pairs(self.nodes) do
        self.debug.nodes[nodeId] = {
            voltage = node.voltage,
            isFixed = node.isFixed,
            connections = #node.connections
        }
    end

    -- Track component states
    for _, comp in ipairs(self.components) do
        if comp.component.mode == "regen" then
            -- Calculate motor-side power
            local motorVoltage = math.abs(comp.component.voltage)
            local motorCurrent = math.abs(comp.component.amperage)
            local motorPower = motorVoltage * motorCurrent
            
            -- Calculate battery-side power with losses
            local efficiency = comp.component.regenEfficiency or 0.7  -- Default to 70% if not specified
            local batteryPower = motorPower * efficiency
            
            -- Calculate battery current from power (P = VI)
            local currentContribution = 0
            if self.battery and self.battery.voltage > 0 then
                local batteryCurrent = batteryPower / self.battery.voltage
                -- Ensure current is negative for charging and reasonable
                currentContribution = -math.min(batteryCurrent, motorCurrent)
            end
            
            -- Store debug info
            if self.debug then
                table.insert(self.debug.battery.regenComponents, {
                    name = comp.name,
                    motorVoltage = motorVoltage,
                    motorCurrent = motorCurrent,
                    motorPower = motorPower,
                    batteryPower = batteryPower,
                    efficiency = efficiency,
                    currentContribution = currentContribution
                })
            end
        end
        
        table.insert(self.debug.components, {
            name = comp.name,
            nodeA = comp.nodeA,
            nodeB = comp.nodeB,
            voltage = comp.component.voltage,
            current = comp.component.amperage,
            mode = comp.component.mode,
            conductance = comp.component:getConductance()
        })
    end

    local debug_output = ""
    
    -- Count non-ground, non-fixed nodes
    local n = 0
    local nodeToIndex = {}  -- Map node IDs to matrix indices
    local indexToNode = {}  -- Map matrix indices to node IDs
    
    -- Build node mapping, skipping ground and fixed voltage nodes
    for nodeId = 2, self.nextNodeId - 1 do
        if not self.nodes[nodeId].isFixed then
            n = n + 1
            nodeToIndex[nodeId] = n
            indexToNode[n] = nodeId
        end
    end
    
    if n < 1 then return end  -- Nothing to solve
    
    -- Create conductance matrix G and current vector I
    local G = matrix.new(n, n)
    local I = matrix.new(n, 1)
    
    -- Build matrices
    for _, comp in ipairs(self.components) do
        local nodeA = comp.nodeA
        local nodeB = comp.nodeB
        local conductance = comp.component:getConductance()
        if conductance < 1e-12 then
            conductance = 1e-12
        end
        
        -- Get current contribution from component
        local currentContribution = comp.component:getCurrentContribution()
        
        -- Handle connections to non-fixed nodes
        if nodeToIndex[nodeA] then
            local idxA = nodeToIndex[nodeA]
            G[idxA][idxA] = G[idxA][idxA] + conductance
            -- Add current contribution to node A
            I[idxA][1] = I[idxA][1] + currentContribution
            
            -- Current contribution from fixed nodes
            if self.nodes[nodeB].isFixed then
                I[idxA][1] = I[idxA][1] + conductance * self.nodes[nodeB].fixedVoltage
            end
        end
        
        if nodeToIndex[nodeB] then
            local idxB = nodeToIndex[nodeB]
            G[idxB][idxB] = G[idxB][idxB] + conductance
            -- Add current contribution to node B (opposite direction)
            I[idxB][1] = I[idxB][1] - currentContribution
            
            -- Current contribution from fixed nodes
            if self.nodes[nodeA].isFixed then
                I[idxB][1] = I[idxB][1] + conductance * self.nodes[nodeA].fixedVoltage
            end
        end
        
        -- Connection between two non-fixed nodes
        if nodeToIndex[nodeA] and nodeToIndex[nodeB] then
            local idxA = nodeToIndex[nodeA]
            local idxB = nodeToIndex[nodeB]
            G[idxA][idxB] = G[idxA][idxB] - conductance
            G[idxB][idxA] = G[idxB][idxA] - conductance
        end
    end
    
    -- Debug matrix state
    --print("Conductance Matrix G:")
    --for i = 1, n do
    --    local row = ""
    --    for j = 1, n do
    --        row = row .. string.format(" %.3f", G[i][j])
    --    end
    --    print(row)
    --end
    --
    --print("Current Vector I:")
    --for i = 1, n do
    --    print(string.format("%.3f", I[i][1]))
    --end
    
    -- Solve system GV = I for node voltages
    local V = matrix.solve(G, I)
    
    -- Update node voltages
    for i = 1, n do
        local nodeId = indexToNode[i]
        self.nodes[nodeId].voltage = V[i][1]
    end
    
    -- Ensure battery nodes maintain correct voltage
    if self.battery then
        self.nodes[self.batteryPos].voltage = self.battery.voltage
    end
    
    -- Debug battery current calculation
    if self.battery then
        if self.debug then
            debug_output = debug_output .. "Battery found, current before update: " .. self.battery.amperage .. "\n"
        end
        self.battery.amperage = 0
    elseif self.debug then
        debug_output = debug_output .. "No battery component found!\n"
    end
    
    -- Debug node voltages after solving
    if self.debug then
        debug_output = debug_output .. "\nNode voltages:\n"
        for nodeId, node in pairs(self.nodes) do
            debug_output = debug_output .. string.format("Node %d: %.1fV\n", nodeId, node.voltage)
        end
    end
    
    -- Update components with solved voltages and calculate total currents
    for _, comp in ipairs(self.components) do
        local vA = self.nodes[comp.nodeA].voltage
        local vB = self.nodes[comp.nodeB].voltage
        local vDiff = vB - vA
        
        if self.debug then
            debug_output = debug_output .. string.format("Component %s: vA=%.1fV, vB=%.1fV, vDiff=%.1fV\n", 
                comp.name,  -- Use stored component name
                vA, vB, vDiff)
        end
        
        -- Update component state (skip battery, we'll update it after currents are summed)
        if comp.component ~= self.battery then
            comp.component:update(vDiff, dt)
        end
        
        -- Calculate branch current for battery
        if self.battery and (comp.nodeA == self.batteryPos or comp.nodeB == self.batteryPos) then
            if comp.component.amperage then
                local currentContribution = comp.component.amperage
                
                -- During regen mode, calculate power flow
                if comp.component.mode == "regen" then
                    -- Get motor values
                    local motorVoltage = math.abs(comp.component.voltage)
                    local motorCurrent = math.abs(comp.component.amperage)
                    local motorPower = motorVoltage * motorCurrent
                    
                    -- Calculate battery charging power
                    local efficiency = comp.component.regenEfficiency or 0.7
                    local batteryChargePower = motorPower * efficiency
                    
                    -- Calculate charging current
                    if self.battery.voltage > 0 then
                        -- P = VI -> I = P/V
                        local chargeCurrent = batteryChargePower / self.battery.voltage
                        
                        -- Limit charging current
                        local maxChargeCurrent = 100  -- 100A max charging
                        chargeCurrent = math.min(chargeCurrent, maxChargeCurrent)
                        
                        -- Make current negative for charging
                        currentContribution = -chargeCurrent
                    else
                        currentContribution = 0
                    end
                    
                    -- Debug info
                    if self.debug then
                        debug_output = debug_output .. string.format(
                            "Regen: MotorP=%.1fW, BattP=%.1fW, Eff=%.1f%%, I=%.1fA\n",
                            motorPower, batteryChargePower, efficiency * 100, currentContribution
                        )
                    end
                end
                
                -- Add current contribution to battery
                if comp.nodeA == self.batteryPos then
                    self.battery.amperage = self.battery.amperage - currentContribution
                else
                    self.battery.amperage = self.battery.amperage + currentContribution
                end
            end
        end
    end
    
    -- Now update battery with accumulated current
    if self.battery then
        local battery_debug = self.battery:update(self.battery.amperage, dt)
        if self.debug then
            debug_output = debug_output .. battery_debug
        end
    end
    
    return debug_output
end


return CircuitSolver 