using CSV
using DataFrames
using CategoricalArrays
using Dates

rootdata = "../../data/HLYM"
#
# read the data files and return as DataFrames
# 
#
function read_items()

    # Master Data and Prices, prices are added as a new column to Master Data

    # read master data, columns names are concatenation of 2 first rows, all string are stripped
    master = CSV.read("$rootdata/HLYM Master Data.csv", DataFrame, stripwhitespace=true, groupmark = ',', header = [1,2])
    # remove the underscores and 'Column' in the name coming second row
    rename!(master, replace.(names(master), r"_Column(\d)+|_" => ""))
    # replace space by underscore
    rename!(master, replace.(names(master), " " => "_"))
    # uppercase
    rename!(master, uppercase.(names(master)))
 
    # add the values
    prices = CSV.read("$rootdata/HLYM Prices.csv", DataFrame)
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
# demand data will not be used in the future, it is replaced by the sales data
function read_demand()
    # Demand
    demand = CSV.read("$rootdata/HLYM Demands.csv", DataFrame)
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

# read the supply data (customer sales)
function read_supply()
    supply = CSV.read("$rootdata/Supply Ratio.csv", DataFrame, stripwhitespace=true, groupmark = ',')
    # rename columns to remove spaces and uppercase
    rename!(supply, uppercase.(replace.(names(supply), " " => "_")))
    # cleanup a few names
    rename!(supply, "DELIVERED_QTY" => "DELIVERED_QUANTITY")
    # convert dates
    supply[!,:ORDER_DATE] = DateTime.(supply[!,:ORDER_DATE],DateFormat("dd/mm/yyy HH:MM"))
    supply[!,:DELIVERY_DATE] = DateTime.(supply[!,:DELIVERY_DATE],DateFormat("dd/mm/yyy HH:MM"))

    # remove old data
    subset!(supply, :ORDER_DATE => ByRow(d->year(d) >= 2022))

    return supply
end

# read the delivery data (suppliers)
function read_delivery()
    delivery = CSV.read("$rootdata/Delivery Ratio.csv", DataFrame, stripwhitespace=true, groupmark = ',')
    # rename columns to remove spaces and uppercase
    rename!(delivery, uppercase.(replace.(names(delivery), " " => "_")))
    # cleanup a few names
    rename!(delivery, "ORDER_QTY" => "ORDERED_QUANTITY")
    rename!(delivery, "DELIVERED_QTY" => "DELIVERED_QUANTITY")
    # remove bad rows
    subset!(delivery, :ORDER_DATE => ByRow(!ismissing))
    delivery[!,:ORDER_DATE] = Date.(delivery[!,:ORDER_DATE],DateFormat("d/m/yyy"))
    delivery[!,:DELIVERY_DATE] = map(delivery[!,:DELIVERY_DATE]) do s ismissing(s) ? s : Date(s,DateFormat("d/m/yyy")) end
    return delivery
end