include("src/utils.jl")
include("src/read_data.jl")
include("src/plot_data.jl")
include("src/forecast.jl")

items = read_items()
demand = read_demand()
