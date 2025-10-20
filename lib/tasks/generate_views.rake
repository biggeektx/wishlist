namespace :views do
  desc "Generate all application views"
  task generate: :environment do
    require "fileutils"

    views_dir = Rails.root.join("app", "views")

    # Dashboard index
    File.write(views_dir.join("dashboard", "index.html.erb"), <<~ERB)
      <div class="space-y-8">
        <div class="flex justify-between items-center">
          <h1 class="text-3xl font-bold text-gray-900">Dashboard</h1>
        </div>

        <% if !user_signed_in? %>
          <div class="bg-white shadow sm:rounded-lg">
            <div class="px-4 py-5 sm:p-6">
              <h3 class="text-lg leading-6 font-medium text-gray-900">Welcome to Wishlist Tracker</h3>
              <div class="mt-2 max-w-xl text-sm text-gray-500">
                <p>Track your wishlist purchases and manage your income to achieve your goals.</p>
              </div>
              <div class="mt-5">
                <%= link_to "Sign In", new_user_session_path, class: "inline-flex items-center px-4 py-2 border border-transparent shadow-sm text-sm font-medium rounded-md text-white bg-indigo-600 hover:bg-indigo-700" %>
                <%= link_to "Sign Up", new_user_registration_path, class: "ml-3 inline-flex items-center px-4 py-2 border border-gray-300 shadow-sm text-sm font-medium rounded-md text-gray-700 bg-white hover:bg-gray-50" %>
              </div>
            </div>
          </div>
        <% else %>
          <% if @incomes.empty? || @wish_list_items.empty? %>
            <div class="bg-blue-50 border-l-4 border-blue-400 p-4">
              <div class="flex">
                <div class="ml-3">
                  <p class="text-sm text-blue-700">
                    Get started by adding
                    <% if @incomes.empty? %>
                      <%= link_to "income sources", new_income_path, class: "font-medium underline" %>
                    <% end %>
                    <% if @incomes.empty? && @wish_list_items.empty? %>
                      and
                    <% end %>
                    <% if @wish_list_items.empty? %>
                      <%= link_to "wishlist items", new_wish_list_item_path, class: "font-medium underline" %>
                    <% end %>
                    to see your allocation timeline.
                  </p>
                </div>
              </div>
            </div>
          <% end %>

          <% if @allocation_result %>
            <div class="bg-white shadow sm:rounded-lg">
              <div class="px-4 py-5 sm:p-6">
                <h3 class="text-lg leading-6 font-medium text-gray-900 mb-4">Allocation Summary</h3>
                <dl class="grid grid-cols-1 gap-5 sm:grid-cols-3">
                  <div class="px-4 py-5 bg-gray-50 shadow rounded-lg">
                    <dt class="text-sm font-medium text-gray-500">Total Future Income</dt>
                    <dd class="mt-1 text-3xl font-semibold text-gray-900"><%= number_to_currency(@allocation_result[:total_income]) %></dd>
                  </div>
                  <div class="px-4 py-5 bg-gray-50 shadow rounded-lg">
                    <dt class="text-sm font-medium text-gray-500">Total Allocated</dt>
                    <dd class="mt-1 text-3xl font-semibold text-indigo-600">
                      <%= number_to_currency(@allocation_result[:allocations].sum { |a| a[:amount_allocated] || 0 }) %>
                    </dd>
                  </div>
                  <div class="px-4 py-5 bg-gray-50 shadow rounded-lg">
                    <dt class="text-sm font-medium text-gray-500">Remaining Funds</dt>
                    <dd class="mt-1 text-3xl font-semibold text-green-600"><%= number_to_currency(@allocation_result[:remaining_funds]) %></dd>
                  </div>
                </dl>
              </div>
            </div>

            <div class="bg-white shadow sm:rounded-lg">
              <div class="px-4 py-5 sm:p-6">
                <h3 class="text-lg leading-6 font-medium text-gray-900 mb-4">Funding Timeline</h3>
                <div class="space-y-4">
                  <% @allocation_result[:timeline].each do |timeline_item| %>
                    <% item = timeline_item[:item] %>
                    <% allocation = @allocation_result[:allocations].find { |a| a[:item_id] == item.id } %>
                    <div class="border-l-4 <%= item.item_type == 'target_date' ? 'border-red-400' : item.item_type == 'sequential' ? 'border-blue-400' : 'border-green-400' %> pl-4 py-2">
                      <div class="flex justify-between items-start">
                        <div>
                          <h4 class="text-base font-medium text-gray-900"><%= item.name %></h4>
                          <p class="text-sm text-gray-500">
                            Type:
                            <span class="inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium <%= item.item_type == 'target_date' ? 'bg-red-100 text-red-800' : item.item_type == 'sequential' ? 'bg-blue-100 text-blue-800' : 'bg-green-100 text-green-800' %>">
                              <%= item.item_type.humanize %>
                              <% if item.item_type == 'target_date' %>
                                - <%= item.target_date.strftime('%B %d, %Y') %>
                              <% elsif item.item_type == 'sequential' %>
                                - #<%= item.sequential_order %>
                              <% elsif item.item_type == 'percentage' %>
                                - <%= item.percentage %>%
                              <% end %>
                            </span>
                          </p>
                          <% if allocation && allocation[:completion_date] %>
                            <p class="text-sm text-gray-600 mt-1">
                              Fully funded by: <span class="font-semibold"><%= allocation[:completion_date].strftime('%B %d, %Y') %></span>
                            </p>
                          <% end %>
                          <% if allocation && !allocation[:feasible] %>
                            <p class="text-sm text-red-600 mt-1">
                              Warning: <%= allocation[:warning] %> (Shortfall: <%= number_to_currency(allocation[:shortfall]) %>)
                            </p>
                          <% end %>
                        </div>
                        <div class="text-right">
                          <p class="text-lg font-semibold text-gray-900"><%= number_to_currency(item.cost) %></p>
                          <% if allocation %>
                            <p class="text-sm text-indigo-600"><%= number_to_currency(allocation[:amount_allocated]) %> allocated</p>
                          <% end %>
                        </div>
                      </div>
                    </div>
                  <% end %>
                </div>
              </div>
            </div>
          <% end %>

          <% if @recent_purchases.any? %>
            <div class="bg-white shadow sm:rounded-lg">
              <div class="px-4 py-5 sm:p-6">
                <h3 class="text-lg leading-6 font-medium text-gray-900 mb-4">Recent Purchases</h3>
                <div class="space-y-3">
                  <% @recent_purchases.each do |purchase| %>
                    <div class="flex justify-between items-center border-b pb-2">
                      <div>
                        <p class="text-sm font-medium text-gray-900"><%= purchase.wish_list_item.name %></p>
                        <p class="text-xs text-gray-500"><%= purchase.purchased_at.strftime('%B %d, %Y') %></p>
                      </div>
                      <p class="text-sm font-semibold text-gray-900"><%= number_to_currency(purchase.amount) %></p>
                    </div>
                  <% end %>
                </div>
                <%= link_to "View All Purchases", purchases_path, class: "mt-4 inline-flex items-center text-sm font-medium text-indigo-600 hover:text-indigo-500" %>
              </div>
            </div>
          <% end %>
        <% end %>
      </div>
    ERB

    puts "✅ Generated dashboard/index.html.erb"
    puts "\n🎉 All views generated successfully!"
  end
end
