using CSV
using DataFrames
using CategoricalArrays
using Dates

#
# read the data files and return as DataFrames
# 
#
function read_items()

    # Master Data and Prices, prices are added as a new column to Master Data

    # read master data, columns names are concatenation of 2 first rows, all string are stripped
    master = CSV.read("data/HLYM Master Data.csv", DataFrame, stripwhitespace=true, groupmark = ',', header = [1,2])
    # remove the underscores and 'Column' in the name coming second row
    rename!(master, replace.(names(master), r"_Column(\d)+|_" => ""))
    # replace space by underscore
    rename!(master, replace.(names(master), " " => "_"))
    # uppercase
    rename!(master, uppercase.(names(master)))
 
    # add the values
    prices = CSV.read("data/HLYM Prices.csv", DataFrame)
    # the prices have duplicates, keep the highest values
    rename!(prices, ["ITEM","VALUE"])
    prices = combine(groupby(prices,:ITEM), :VALUE => maximum => :VALUE)
    master = leftjoin(master, prices, on = :ITEM)

    # ABC remove missing and categorize
    subset!(master, :ABC => ByRow(!ismissing))
    master[!,:ABC] = categorical(master[!,:ABC],ordered=true)

    # remove the 20 products without product group
    subset!(master, :PRODUCTGROUP => ByRow(!ismissing))

    return master
end

# read and unpivot demand data
function read_demand()
    # Demand
    demand = CSV.read("data/HLYM Demands.csv", DataFrame)
    # Unpivot
    demand = stack(demand, Not(:Item), variable_name = :MONTH, value_name = :DEMAND)
    # # change month to Dates
    demand[!,:MONTH] = Date.(demand[!,:MONTH],DateFormat("yyyymm"))
    #change missing and negative demand to zero
    demand[!,:DEMAND] = map(demand[!,:DEMAND]) do x max(coalesce(x,0),0) end
    # set integer
    demand[!,:DEMAND] = floor.(Int,demand[!,:DEMAND])
    # uppercase column names
    rename!(demand, uppercase.(names(demand)))
    sort!(demand, [:ITEM, :MONTH])
    return demand
end

