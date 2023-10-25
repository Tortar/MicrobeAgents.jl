using MicrobeAgents, Test
using Random
using LinearAlgebra: norm

@testset "Model stepping" begin
    for D in 1:3, ABM in (StandardABM, UnremovableABM)
        rng = Xoshiro(68)
        dt = 1
        extent = fill(300.0, SVector{D})
        space = ContinuousSpace(extent)
        model = ABM(Microbe{D}, space, dt; rng)
        pos = extent ./ 2
        vel1 = random_velocity(model)
        speed1 = random_speed(rng, RunTumble())
        add_agent!(pos, model; vel=vel1, speed=speed1, turn_rate=0)
        vel2 = random_velocity(model)
        speed2 = random_speed(rng, RunReverse())
        add_agent!(pos, model; vel=vel2, speed=speed2, turn_rate=Inf, motility=RunReverse())
        run!(model, 1) # performs 1 microbe_step!
        # x₁ = x₀ + vΔt
        @test all(model[1].pos .≈ pos .+ vel1 .* speed1 .* dt)
        @test all(model[2].pos .≈ pos .+ vel2 .* speed2 .* dt)
        # v is the same for the agent with zero turn rate
        @test all(model[1].vel .≈ vel1)
        # v is changed for the other agent
        @test ~all(model[2].vel .≈ vel2)
        # and since it turned its motile state changed from Forward to Backward
        @test model[2].motility.state == Backward

        # customize microbe affect! function
        # decreases microbe state value by D at each step
        MicrobeAgents.affect!(microbe::Microbe{D}, model) = (microbe.state -= D)
        model = ABM(Microbe{D}, space, dt)
        add_agent!(model)
        run!(model, 1)
        @test model[1].state == -D
        # restore default affect! function
        MicrobeAgents.affect!(microbe::Microbe{D}, model) = nothing
        run!(model, 1)
        # now the state has not changed from previous step
        @test model[1].state == -D

        # customize model_step! function
        model_step!(model) = model.t += 1
        model = ABM(Microbe{D}, space, dt; model_step!)
        run!(model, 6)
        @test model.t == 6
    end
end