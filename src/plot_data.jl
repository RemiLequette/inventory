
using Plots
using Plots.PlotMeasures
using StatsPlots
using Statistics
using Distributions

get_colors() = [:red, :blue, :green, :yellow, :silver, :orange, :brown, :pink, :cyan, :magenta, :gray, :lime, :olive]

function stackedbar(df,x_col,value_col,group_col; kwargs...)
    return groupedbar(df[!,x_col],df[!,value_col],groups=df[!,group_col], bar_position=:stack; kwargs...)
end


# plot demand for a list of items (of to plot an additional forecast)
function plot_demand(df,litem; mm = true, trend = false, window = 12, of = nothing, with_outliers = false)
    if typeof(litem) <: AbstractString || typeof(litem) <: Symbol
        litem = [litem]
    end	
    n = length(litem)
    plot(map(litem) do i 
        it = df[!,:ITEM] .== i
        months, demands = df[it,:MONTH], df[it,:DEMAND]
        p = bar(months,demands, bar_width = 20, label = i)
        if with_outliers
            o = outliers(demands)
            bar!(p,months[o],demands[o], color = :red, bar_width = 20, label = "outliers")
        end
        if mm plot!(p,months[1+window:end], ma(demands,window), color = :black, width = 3, label = "12 months mean") end
        if trend
            c = lr(demands)
            plot!(p,[months[1],months[end]], [c[2], c[2]+c[1]*(length(months)-1)], color = :red, width = 3, label = "trend")
        end
        if !isnothing(of)
            forecast = of(df[it,:DEMAND])
            plot!(p,months[end-length(forecast)+1:end], forecast, color = :green, width = 3, label = string(Symbol(of)))
        end
        return p
    end ..., layout = (n,1),size = (900,300*n), left_margin = 40px)
end


# histogram of demand for a list of items
function histo_demand(df,litem; normal = true, lognormal = false, gamma = true)
    n = length(litem)
    plot(map(litem) do i 
        it = df[!,:ITEM] .== i
        demands = df[it,:DEMAND]      
        p = histogram(demands, norm = true, bins=:scott, label = i)
        if normal || lognormal || gamma
            min,max = extrema(demands)
            x = range(min,stop = max,length = 100)
            μ,σ = mean(demands), std(demands)
            normal && plot!(p,x, pdf(Normal(μ,σ),x), color = :red, label = "normal", linewidth = 2)
            if lognormal
                ldemands = log.(demands)
                lμ,lσ = mean(ldemands), std(ldemands)
                @show lμ,lσ
                plot!(p,x, pdf(LogNormal(lμ,lσ),x), color = :yellow, label = "lognormal", linewidth = 2)
            end
            if gamma
                α,β = μ^2/σ^2, σ^2/μ
                plot!(p,x, pdf(Gamma(α,β),x), color = :green, label = "gamma", linewidth = 2)
            end
        end
        return p
    end ..., layout = (n,1),size = (800,300*n))
end

function plot_inventory(df,items)
    n = length(items)
    plot(map(items) do i
        it = df[!,:ITEM] .== i
        p = plot(df[it,:DATE],df[it,:INV_ONHAND], label = "on hand", xlabel = "date", ylabel = "quantity", size = (800,300),title="Inventory for $i")
        plot!(p,df[it,:DATE],df[it,:INV_ONORDER], label = "on order")
        plot!(p,df[it,:DATE],df[it,:INV_BACKORDER], label = "backorder")
        return p
    end ..., layout = (n,1),size = (800,300*n))
end

function plot_sales(df, item)
    d_it = filter(row -> row.ITEM == item, eachrow(df))
    p = plot(d_it.ORDER_DATE,d_it.ORDERED_QUANTITY, label = "order quantity", xlabel = "date", ylabel = "quantity", size = (800,300))
    return p
end
