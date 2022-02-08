"""
    evolve!(curr::Field, prev::Field, a, dt)

Calculate a new temperature field curr based on the previous 
field prev. a is the diffusion constant and dt is the largest 
stable time step.    
"""
function evolve!(curr::Field, prev::Field, a, dt)
    for j = 2:curr.ny+1
        for i = 2:curr.nx+1
            xderiv = (prev.data[i-1, j] - 2.0 * prev.data[i, j] + prev.data[i+1, j]) / curr.dx^2
            yderiv = (prev.data[i, j-1] - 2.0 * prev.data[i, j] + prev.data[i, j+1]) / curr.dy^2
            curr.data[i, j] = prev.data[i, j] + a * dt * (xderiv + yderiv)
        end 
    end
end

function evolve_gpu!(currdata, prevdata, dx2, dy2, a, dt)
    nx, ny = size(currdata)    
    j = blockIdx.x * blockDim.x + threadIdx.x
    i = blockIdx.y * blockDim.y + threadIdx.y

    if i > 1 && j > 1 && i < nx+2 && j < ny+2
        xderiv = (prevdata[i-1, j] - 2.0 * prevdata[i, j] + prevdata[i+1, j]) / dx2
        yderiv = (prevdata[i, j-1] - 2.0 * prevdata[i, j] + prevdata[i, j+1]) / dy2
        currdata[i, j] = prevdata[i, j] + a * dt * (xderiv + yderiv)
    end
end

"""
    swap_fields!(curr::Field, prev::Field)

Swap the data of two fields curr and prev.    
"""    
function swap_fields!(curr::Field, prev::Field)
    tmp = curr.data
    curr.data = prev.data
    prev.data = tmp
end

""" 
    average_temperature(f::Field)

Calculate average temperature of a temperature field.        
"""
average_temperature(f::Field) = sum(f.data[2:f.nx+1, 2:f.ny+1]) / (f.nx * f.ny)

"""
    simulate!(current, previous, nsteps)

Run the heat equation solver on fields curr and prev for nsteps.
"""
function simulate!(curr::Field, prev::Field, nsteps)

    println("Initial average temperature: $(average_temperature(curr))")

    # Diffusion constant
    a = 0.5
    # Largest stable time step
    dt = curr.dx^2 * curr.dy^2 / (2.0 * a * (curr.dx^2 + curr.dy^2))
    
    # display a nice progress bar
    p = Progress(nsteps)

    for i = 1:nsteps
        # calculate new state based on previous state
        if typeof(curr.data) <: CuArray
            @cuda (curr.nx, curr.ny) evolve_gpu!(curr.data, prev.data, curr.dx^2, curr.dy^2, a, dt)
        else
            evolve!(curr, prev, a, dt)
        end
        # swap current and previous fields
        swap_fields!(curr, prev)

        # increment the progress bar
        next!(p)
    end 

    # print final average temperature
    println("Final average temperature: $(average_temperature(curr))")
end
