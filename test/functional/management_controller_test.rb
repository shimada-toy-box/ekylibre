require 'test_helper'

class ManagementControllerTest < ActionController::TestCase
  fixtures :companies, :users
  test_all_actions(
                   :delivery_create=>{:order_id=>3},
                   :delivery_update=>{:id=>1},
                   :embankment_create=>{:mode_id=>1}, 
                   :inventory_reflect=>:delete, 
                   :invoice_cancel=>:update, 
                   :product_component_create=>{:product_id=>1}, 
                   :purchase_order_summary=>:select, 
                   :purchase_order_lines=>:select, 
                   :purchase_order_line_create=>{:order_id=>1},
                   :purchase_payment_part_create=>{:expense_id=>1},
                   :sale_order_confirm=>:delete,
                   :sale_order_deliveries=>:select, 
                   :sale_order_invoice=>:delete,
                   :sale_order_summary=>:select, 
                   :sale_order_line_create=>{:order_id=>1},
                   :sale_order_lines=>:select, 
                   :sale_payment_part_create=>{:expense_type=>"sale_order", :expense_id=>1},
                   :subscription_nature_increment=>:delete,
                   :subscription_nature_decrement=>:delete, 
                   :transport_deliveries=>:select, 
                   :except=>[:change_quantities, 
                             :subscription_coordinates,
                             :price_find, 
                             :unpaid_sale_orders_export,
                             :subscription_nature, 
                             :subscription_find, 
                             :subscription_message, 
                             :subscription_options, 
                             :subscriptions_period, 
                             :sale_order_line_informations,
                             :sale_order_line_stocks,
                             :sale_order_line_tracking,
                             :sale_order_contacts, 
                             :product_trackings, 
                             :sum_calculate,
                             :prices_export,
                             :product_units]
                   )
end
