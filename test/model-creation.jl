using MicrobeAgents, Test
using LinearAlgebra: norm

@testset "Model creation" begin
    for D in 1:3
        timestep = 1
        space = ContinuousSpace(ones(SVector{D}))
        model = StandardABM(Microbe{D}, space, timestep)
        @test model isa StandardABM
        @test Set(keys(abmproperties(model))) == Set((
            :timestep,
            :chemoattractant,
            :affect!
        ))
    end

    @testset "Base Microbe type" begin
        for D in 1:3
            timestep = 1
            space = ContinuousSpace(ones(SVector{D}))
            model = StandardABM(Microbe{D}, space, timestep; rng=Xoshiro(123))
            # add agent with default constructor
            # random pos and vel, random speed from motility pattern
            add_agent!(model)
            rng = Xoshiro(123)
            pos = rand(rng, SVector{D})
            vel = random_velocity(rng, D)
            #speed = random_speed(rng, RunTumble())
            spd = rand(rng, speed(RunTumble()))
            @test model[1] isa Microbe{D}
            @test position(model[1]) == pos
            @test direction(model[1]) == vel
            @test speed(model[1]) == spd
            @test turnrate(model[1]) == 1.0
            @test radius(model[1]) == 0.0
            @test rotational_diffusivity(model[1]) == 0.0
            @test state(model[1]) == 0.0
            # add agent with kwproperties
            motility = RunReverse(
                speed_backward = [24.0],
                motile_state = MotileState(Backward)
            )
            add_agent!(model; turn_rate = 0.55, motility)
            @test model[2].turn_rate == 0.55
            @test model[2].speed == 24.0
            # add agent with predefined position
            pos = SVector{D}(i/2D for i in 1:D)
            add_agent!(pos, model)
            @test model[3].pos == pos
        end
    end

    @testset "Chemotactic Microbe types" begin
        for T in [BrownBerg, Celani, Xie, Brumley], D in 1:3
            @testset "$(T{D})" begin
                timestep = 1
                space = ContinuousSpace(ones(SVector{D}))
                model = StandardABM(T{D}, space, timestep; rng=Xoshiro(987))
                rng = Xoshiro(987)
                add_agent!(model)
                m = model[1]
                @test m isa T{D}
                @test position(m) == rand(rng, SVector{D})
                @test direction(m) == random_velocity(rng, D)
                @test speed(m) == rand(rng, speed(motilepattern(m)))
                @test issubset(
                    (:id, :pos, :vel, :speed, :motility,
                    :rotational_diffusivity, :radius, :state),
                    fieldnames(T)
                )

                φ(microbe, model) = turnrate(microbe) * tumblebias(microbe)
                if T == BrownBerg
                    @test φ(m, model) == m.turn_rate * exp(-m.gain*m.state)
                elseif T == Brumley
                    @test φ(m, model) == (1+exp(-m.gain*m.state))*m.turn_rate/2
                elseif T == Celani
                    @test φ(m, model) == m.turn_rate * (1 - m.gain*m.state)
                    # when no concentration field is set, markovian variables are zero
                    @test m.markovian_variables == zeros(3)

                    # initialize a new model with non-zero concentration field
                    C = 2.0
                    concentration_field(pos, model) = C
                    chemoattractant = GenericChemoattractant{D,Float64}(;concentration_field)
                    properties = Dict(:chemoattractant => chemoattractant)
                    s = ContinuousSpace(ones(SVector{D}))
                    model_c = StandardABM(Celani{D}, s, 1.0; properties)
                    add_agent!(model_c)
                    m = model_c[1]
                    λ = 1 / m.memory
                    @test m.state == 0.0
                    @test m.markovian_variables == [C/λ, C/λ^2, 2C/λ^3]
                elseif T == Xie
                    S = m.state
                    ω = m.turn_rate_forward
                    β = m.gain_forward
                    @test turnrate(m) == ω * (1 + β*S)
                end
            end
        end
    end
end
