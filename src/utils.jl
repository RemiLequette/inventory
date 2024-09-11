using Format
using PrettyTables

using LinearRegression
using Statistics
using LinearAlgebra
using Distributions

# format as money
money(v; currency = "RM ",separator = ",", precision = 0) = currency*pyfmt("$separator.$(precision)f",v)

# format as percentage
percentage(v, precision = 2) = pyfmt(".$(precision)f",v*100)*"%"

# format date as year month
ym(d) = Dates.format(d,"yyyy-mm")

# format a PrettyTables
function pretty(df; rename_cols = [nothing=>nothing], kwargs...)
    function format_value(v,i,j)
        if typeof(v) <: Number
            if endswith(names(df)[j],"_VALUE") || endswith(names(df)[j],"_SALES")
                return money(v)
            elseif endswith(names(df)[j],"_PERCENT")
                return percentage(v)
            elseif typeof(v) <: Bool
                return v ? "Y" : "N"
            else
                return pyfmt(".2f",v)
            end
        elseif typeof(v) <: Dates.Date
            return ym(v)
        else
            return v
        end
    end
    return PrettyTables.pretty_table(HTML,df, header=replace(propertynames(df),rename_cols...), formatters=format_value, kwargs...)
end	

# remove colums if exists
function remove_columns!(df,cols)
    c = intersect(propertynames(df),cols)
    if !isempty(c)
        select!(df, Not(c))
    end
end

ma(demands,window = 12) = [round(Int,mean(demands[t-window:t-1])) for t in 1+window:length(demands)]
lr(demands) = coef(linregress(collect(1:length(demands)),demands))



# value of a quantity column
value(items, col) = dot(items[!,:VALUE],items[!,col])

inventory_value(items) = value(items,:INV_ONHAND)

# fill rate for next period, compare the demand with the inventory on hand + on order - backorder
fill_rate(items) = sum(items[!,:INV_ONHAND])/sum(items[!,:VALUE])

# extract value by ABC
# aggegate by dot(:VALUE, quantity)
# return a dataframe with ABC and INV_VALUE
function abc_values(items, quantity = :INV_ONHAND)
    c = combine(groupby(items,:ABC,skipmissing=true),[:VALUE,quantity] => dot => :VALUE)
    sort!(c)
    return c
end

function split_by_demand(items,demand) 
    items_demand_set = Set(names(demand)[2:end])
    items_with_demand = subset(items, :ITEM => ByRow(x -> x ∈ items_demand_set))
    items_without_demand = subset(items, :ITEM => ByRow(x -> x ∉ items_demand_set))
    return items_with_demand, items_without_demand
end