
using Plots
using StatsPlots
using Statistics
using Distributions

#colors() = [:red, :blue, :green, :yellow, :silver, :orange, :brown, :pink, :cyan, :magenta, :gray, :lime, :olive]

function stackedbar(df,x_col,value_col,group_col; kwargs...)
    return groupedbar(df[!,x_col],df[!,value_col],groups=df[!,group_col], bar_position=:stack; kwargs...)
end


# plot demand for a list of items
function plot_demand(df,litem; mm = true, trend = true, window = 12)
    if typeof(litem) <: AbstractString || typeof(litem) <: Symbol
        litem = [litem]
    end	
    n = length(litem)
    plot(map(litem) do i 
        it = df[!,:ITEM] .== i
        months, demands = df[it,:MONTH], df[it,:DEMAND]
        p = bar(months,demands, label = i)
        if mm plot!(p,months[1+window:end], ma(demands,window), color = :black, width = 3, label = "mm") end
        if trend
            c = lr(demands)
            plot!(p,[months[1],months[end]], [c[2], c[2]+c[1]*(length(months)-1)], color = :red, width = 3, label = "trend")
        end
        return p
    end ..., layout = (n,1),size = (800,300*n))
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

