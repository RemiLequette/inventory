include("src/utils.jl")
include("src/read_data.jl")
include("src/plot_data.jl")

include("src/simulation.jl")


function test()
    df_supply = read_supply()
    df_delivery = read_delivery()
    df_inventory = simulate_items(df_supply, df_delivery; ritem = r"MCD-COL60-WH-2L", log=1, alldays = true)
    plot_inventory(df_inventory, unique(df_inventory.ITEM)[1:1])
end

test()
