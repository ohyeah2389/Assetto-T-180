local matrix = {}


function matrix.new(rows, cols)
    local m = {}
    for i = 1, rows do
        m[i] = {}
        for j = 1, cols do
            m[i][j] = 0
        end
    end
    return m
end


function matrix.solve(A, b)
    local n = #A
    local x = matrix.new(n, 1)
    
    -- Create deep copies to prevent modifying original matrices
    local A_copy = {}
    local b_copy = {}
    for i = 1, n do
        A_copy[i] = {}
        for j = 1, #A[i] do
            A_copy[i][j] = A[i][j]
        end
        b_copy[i] = { b[i][1] }
    end
    
    -- Gaussian elimination with partial pivoting
    for k = 1, n-1 do
        local maxVal = math.abs(A_copy[k][k])
        local maxRow = k
        for i = k+1, n do
            if math.abs(A_copy[i][k]) > maxVal then
                maxVal = math.abs(A_copy[i][k])
                maxRow = i
            end
        end
        
        if maxRow ~= k then
            A_copy[k], A_copy[maxRow] = A_copy[maxRow], A_copy[k]
            b_copy[k], b_copy[maxRow] = b_copy[maxRow], b_copy[k]
        end
        
        for i = k+1, n do
            local c = A_copy[i][k] / A_copy[k][k]
            for j = k, n do
                A_copy[i][j] = A_copy[i][j] - c * A_copy[k][j]
            end
            b_copy[i][1] = b_copy[i][1] - c * b_copy[k][1]
        end
    end
    
    -- Back substitution
    for i = n, 1, -1 do
        local sum = b_copy[i][1]
        for j = i+1, n do
            sum = sum - A_copy[i][j] * x[j][1]
        end
        x[i][1] = sum / A_copy[i][i]
    end
    
    return x
end


return matrix 