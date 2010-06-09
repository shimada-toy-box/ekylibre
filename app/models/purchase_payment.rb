# = Informations
# 
# == License
# 
# Ekylibre - Simple ERP
# Copyright (C) 2009-2010 Brice Texier, Thibaud Mérigon
# 
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# any later version.
# 
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
# 
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see http://www.gnu.org/licenses.
# 
# == Table: purchase_payments
#
#  accounted_at      :datetime         
#  amount            :decimal(16, 2)   default(0.0), not null
#  check_number      :string(255)      
#  company_id        :integer          not null
#  created_at        :datetime         not null
#  created_on        :date             
#  creator_id        :integer          
#  id                :integer          not null, primary key
#  journal_record_id :integer          
#  lock_version      :integer          default(0), not null
#  mode_id           :integer          not null
#  number            :string(255)      
#  paid_on           :date             
#  parts_amount      :decimal(16, 2)   default(0.0), not null
#  payee_id          :integer          not null
#  responsible_id    :integer          not null
#  to_bank_on        :date             not null
#  updated_at        :datetime         not null
#  updater_id        :integer          
#

class PurchasePayment < ActiveRecord::Base
  attr_readonly :company_id
  belongs_to :company
  belongs_to :responsible, :class_name=>User.name
  belongs_to :payee, :class_name=>Entity.name
  belongs_to :mode, :class_name=>PurchasePaymentMode.name
  belongs_to :journal_record
  has_many :parts, :class_name=>PurchasePaymentPart.name, :foreign_key=>:payment_id
  has_many :purchase_orders, :through=>:parts

  validates_numericality_of :amount, :greater_than=>0
  validates_presence_of :to_bank_on, :created_on


  def before_validation_on_create
    self.created_on ||= Date.today
    specific_numeration = self.company.parameter("management.purchase_payments.numeration")
    if specific_numeration and specific_numeration.value
      self.number = specific_numeration.value.next_value
    else
      last = self.company.purchase_payments.find(:first, :conditions=>["company_id=? AND number IS NOT NULL", self.company_id], :order=>"number desc")
      self.number = last ? last.number.succ : '000000'
    end
    true
  end

  def before_validation
    self.parts_amount = self.parts.sum(:amount)
  end

  def validate
    errors.add(:amount, :greater_than_or_equal_to, :count=>self.parts_amount) if self.amount < self.parts_amount
  end

  # Create initial journal record
  def after_create
    self.to_accountancy if self.company.accountizing?
  end

  # Add journal records in order to correct accountancy
  def before_update
    self.to_accountancy(:update) if self.company.accountizing?
  end

  def before_destroy
    self.to_accountancy(:delete) if self.company.accountizing?
  end

  def label
    tc(:label, :amount=>self.amount.to_s, :date=>self.created_at.to_date, :mode=>self.mode.name, :usable_amount=>self.unused_amount.to_s, :payee=>self.payee.full_name, :number=>self.number)
  end

  def unused_amount
    self.amount-self.parts_amount
  end


  # Use the minimum amount to pay the expense
  # If the payment is a downpayment, we look at the total unpaid amount
  def pay(expense, options={})
    raise Exception.new("Expense must be PurchaseOrder (not #{expense.class.name})") unless expense.class.name == PurchaseOrder.name
    downpayment = options[:downpayment]
    PurchasePaymentPart.destroy_all(:expense_id=>expense.id, :payment_id=>self.id)
    self.reload
    part_amount = [expense.unpaid_amount(!downpayment), self.unused_amount].min
    part = self.parts.create(:amount=>part_amount, :expense=>expense, :company_id=>self.company_id, :downpayment=>downpayment)
    if part.errors.size > 0
      errors.add_from_record(part)
      return false
    end
    return true
  end


  # This method permits to add journal entries corresponding to the payment
  # It depends on the parameter which permit to activate the "automatic accountizing"
  # The options :old permits to cancel the old existing record by adding counter-entries
  def to_accountancy(action=:create, options={})
    mode = self.mode
    unless mode.with_accounting?
      self.class.update_all({:accounted_at=>Time.now}, {:id=>self.id})
      return
    end
    raise Exception.new("Unvalid action #{action.inspect}") unless [:create, :update, :delete].include? action
    journal = self.company.journal(:bank) # (action == :create ? :bank : :various)
    # Add counter-entries
    ActiveRecord::Base.transaction do
      if action != :create and not self.journal_record.nil?
        if self.journal_record.draft?
          self.journal_record.entries.destroy_all
        else
          self.journal_record.cancel
          self.journal_record = nil
        end
      end
      self.journal_record ||= journal.records.create!(:resource=>self, :printed_on=>self.created_on, :draft_mode=>options[:draft]||self.company.draft_mode?)
      # Add entries
      if action != :delete
        self.journal_record.add_debit( tc(:to_accountancy, :resource=>self.class.human_name, :number=>self.number, :detail=>self.payee.full_name), self.payee.account(:supplier).id, self.amount)
        self.journal_record.add_credit(tc(:to_accountancy, :resource=>self.class.human_name, :number=>self.number, :detail=>self.mode.name), self.mode.cash.account_id, self.amount)
      end
      self.class.update_all({:accounted_at=>Time.now, :journal_record_id=>self.journal_record.id}, {:id=>self.id})
    end 
  end


end
