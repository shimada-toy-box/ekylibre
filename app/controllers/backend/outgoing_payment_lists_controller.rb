# == License
# Ekylibre - Simple agricultural ERP
# Copyright (C) 2008-2011 Brice Texier, Thibaud Merigon
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU Affero General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU Affero General Public License for more details.
#
# You should have received a copy of the GNU Affero General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.
#

module Backend
  class OutgoingPaymentListsController < Backend::BaseController
    manage_restfully only: [:show, :index, :destroy]

    list do |t|
      t.action :destroy, if: :destroyable?
      t.action :export_to_sepa, method: :get, if: :sepa?
      t.column :number, url: true
      t.column :created_at
      t.column :mode
      t.column :payments_count, datatype: :integer
      t.column :payments_sum, label: :total, datatype: :float, currency: true
    end

    list(:payments, model: 'OutgoingPayment', conditions: { list_id: 'params[:id]'.c }) do |t|
      t.column :number, url: true
      t.column :payee, url: true
      t.column :paid_at
      t.column :amount, currency: true, url: true
      t.column :mode
      t.column :bank_check_number
      t.column :to_bank_at
      t.column :work_name, through: :affair, label: :affair_number, url: { controller: :purchase_affairs }
      t.column :deal_work_name, through: :affair, label: :purchase_number, url: { controller: :purchases, id: 'RECORD.affair.deals_of_type(Purchase).first.id'.c }
      t.column :bank_statement_number, through: :journal_entry, url: { controller: :bank_statements, id: 'RECORD.journal_entry.bank_statements.first.id'.c }
    end

    def export_to_sepa
      list = OutgoingPaymentList.find(params[:id])

      if list.sepa?
        send_data(list.to_sepa, filename: "#{list.number}.xml", type: 'text/xml')
      else
        render :index
      end
    end

    def new
      @outgoing_payment_list = OutgoingPaymentList.new
      if params[:started_at].present? && params[:stopped_at].present? && params[:outgoing_payment_list] && params[:outgoing_payment_list][:mode_id]
        mode = OutgoingPaymentMode.find_by(id: params[:outgoing_payment_list][:mode_id])
        @outgoing_payment_list.mode = mode

        if @outgoing_payment_list.valid?
          @thirds = Entity.includes(:purchase_affairs).where(affairs: { closed: false, currency: mode.cash.currency }).where('affairs.updated_at BETWEEN ? AND ?', params[:started_at], params[:stopped_at])
        end
      end
    end

    def create
      if params[:purchase_affairs] && params[:purchase_affairs].present?
        affairs = PurchaseAffair.where(id: params[:purchase_affairs].compact).uniq

        mode_id = params[:outgoing_payment_list][:mode_id] if params[:outgoing_payment_list] && params[:outgoing_payment_list][:mode_id]
        outgoing_payment_list = OutgoingPaymentList.build_from_purchase_affairs affairs, OutgoingPaymentMode.find_by(id: mode_id), current_user, params[:bank_check_number]
        outgoing_payment_list.save!

        redirect_to action: :show, id: outgoing_payment_list.id
      else
        redirect_to new_backend_outgoing_payment_list_path(params.slice(:started_at, :stopped_at, :outgoing_payment_list, :bank_check_number))
      end
    end
  end
end
