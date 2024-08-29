using CSV
using DataFrames
using Dates

#
# read the data files and return as DataFrames
# 
#
function read()
    df = CSV.read("data/HLYM Demands.csv", DataFrame, transpose=true)
    # convert the Item colun to dates and rename it to Month
    rename!(df, :Item => :Month)
    transform!(df,:Month=>(x->map(x) do d Date(d÷100,d%100) end)=>:Month)
    # transform missings to zeros
    transform!(df, names(df)[2:end] .=> (x->coalesce.(x,0)) .=> names(df)[2:end])
    return df
end

