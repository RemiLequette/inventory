using CSV
using DataFrames
using Dates

#
# read the data files and return as DataFrames
# 
#
function read_items()

    # Master Data and Prices, prices are added as a new column to Master Data

    # read master data, columns names are concatenation of 2 first rows, all string are stripped
    master = CSV.read("data/HLYM Master Data.csv", DataFrame, stripwhitespace=true, header = [1,2])
    # remove the underscores and 'Column' in the name coming second row
    rename!(master, replace.(names(master), r"_Column(\d)+|_" => ""))
    # replace space by underscore
    rename!(master, replace.(names(master), " " => "_"))
    # uppercase
    rename!(master, uppercase.(names(master)))
 

    prices = CSV.read("data/HLYM Prices.csv", DataFrame)
    rename!(prices, ["ITEM","VALUE"])
    master = innerjoin(master, prices, on = :ITEM)

    return master
end

function read_demand()
    # Demand
    demand = CSV.read("data/HLYM Demands.csv", DataFrame, transpose=true)
    # convert the Item colun to dates and rename it to Month
    rename!(demand, :Item => :Month)
    transform!(demand,:Month=>(x->map(x) do d Date(d÷100,d%100) end)=>:Month)
    # transform missings to zeros
    transform!(demand, names(demand)[2:end] .=> (x->coalesce.(x,0)) .=> names(demand)[2:end])


    
    return demand
end

