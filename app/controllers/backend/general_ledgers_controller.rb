# == License
# Ekylibre - Simple agricultural ERP
# Copyright (C) 2008-2009 Brice Texier, Thibaud Merigon
# Copyright (C) 2010-2012 Brice Texier
# Copyright (C) 2012-2015 Brice Texier, David Joulin
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
  class GeneralLedgersController < Backend::BaseController
    def self.list_conditions
      code = ''
      code << search_conditions({ journal_entry_item: %i[name debit credit real_debit real_credit] }, conditions: 'c') + "\n"
      code << ledger_crit('params')
      code << journal_period_crit('params')
      code << account_crit('params')
      code << "params[:lettering_state] = ['lettered', 'partially_lettered', 'unlettered']\n"
      code << "preference_basename = 'backend/general_ledgers.journal_entry_items-list' \n"

      code << "if current_user.preference(preference_basename + '.lettered_items.masked', false, :boolean).value \n"
      code << "  params[:lettering_state].reject!{|s| s == 'lettered'}\n"
      code << "end \n"
      code << "states = #{JournalEntry.states}\n"
      code << "if current_user.preference(preference_basename + '.draft_items.masked', false, :boolean).value \n"
      code << "  states.reject!{|s| s == :draft}\n"
      code << "end \n"
      code << "states = states.each_with_object({}) do |v, h| \n"
      code << "  h[v] = v \n"
      code << "end \n"
      code << "params[:states] = states\n"
      code << journal_letter_crit('params')
      code << journal_entries_states_crit('params')
      code << "c\n"
      code.c
    end

    def self.account_conditions
      code = ''
      code << search_conditions({ journal_entry_item: %i[name debit credit real_debit real_credit] }, conditions: 'c') + "\n"
      code << account_journal_period_crit('params')
      code << centralizing_account_crit('params')
      code << "c\n"
      code.c
    end

    def self.centralized_account_conditions
      code = ''
      code << search_conditions({ journal_entry_item: %i[name debit credit real_debit real_credit] }, conditions: 'c') + "\n"
      code << centralizing_account_crit('params')
      code << centralizing_account_journal_period_crit('params')
      code << "c\n"
      code.c
    end

    def self.subledger_accounts_selections
      s = []
      s << ['CASE WHEN (SUM(journal_entry_items.real_debit) - SUM(journal_entry_items.real_credit)) >= 0 THEN SUM(journal_entry_items.real_debit) - SUM(journal_entry_items.real_credit) ELSE 0 END', 'cumulated_absolute_debit_balance']
      s << ['CASE WHEN (SUM(journal_entry_items.real_debit) - SUM(journal_entry_items.real_credit)) < 0 THEN @ SUM(journal_entry_items.real_debit) - SUM(journal_entry_items.real_credit) ELSE 0 END', 'cumulated_absolute_credit_balance']
      s << ['accounts.number']
      s << ['accounts.name'] << ['accounts.description'] << ['accounts.id'] << ['accounts.centralizing_account_id']
      s << ['journal_entry_items.absolute_currency AS account_currency']
    end

    def self.union_subquery
      q1 = %q{Account.select("rpad(accounts.number, 8, '0') AS account_number, accounts.number, accounts.name, accounts.id, accounts.description, CASE WHEN (SUM(journal_entry_items.real_debit) - SUM(journal_entry_items.real_credit)) >= 0 THEN SUM(journal_entry_items.real_debit) - SUM(journal_entry_items.real_credit) ELSE 0 END AS cumulated_absolute_debit_balance, CASE WHEN (SUM(journal_entry_items.real_debit) - SUM(journal_entry_items.real_credit)) < 0 THEN @ SUM(journal_entry_items.real_debit) - SUM(journal_entry_items.real_credit) ELSE 0 END AS cumulated_absolute_credit_balance, journal_entry_items.absolute_currency AS account_currency").joins('INNER JOIN "accounts" AS child ON accounts.id = child.centralizing_account_id').joins('INNER JOIN "journal_entry_items" ON "journal_entry_items"."account_id" = child."id"').joins('INNER JOIN "journal_entries" ON "journal_entries"."id" = "journal_entry_items"."entry_id"').group('accounts.number, accounts.name, accounts.id, accounts.description, account_currency')}

      q2 = %q{Account.select('accounts.number, accounts.number, accounts.name, accounts.id, accounts.description, CASE WHEN (SUM(journal_entry_items.real_debit) - SUM(journal_entry_items.real_credit)) >= 0 THEN SUM(journal_entry_items.real_debit) - SUM(journal_entry_items.real_credit) ELSE 0 END AS cumulated_absolute_debit_balance, CASE WHEN (SUM(journal_entry_items.real_debit) - SUM(journal_entry_items.real_credit)) < 0 THEN @ SUM(journal_entry_items.real_debit) - SUM(journal_entry_items.real_credit) ELSE 0 END AS cumulated_absolute_credit_balance, journal_entry_items.absolute_currency AS account_currency').joins('INNER JOIN "journal_entry_items" ON "journal_entry_items"."account_id" = accounts."id"').joins('INNER JOIN "journal_entries" ON "journal_entries"."id" = "journal_entry_items"."entry_id"').group('accounts.number, accounts.name, accounts.id, accounts.description, account_currency')}

      code = "k = ''\n"
      code << centralized_account_conditions.to_s
      code << "k << '(' \n"
      code << "k << #{q1.c}.where(c).to_sql \n"
      code << "k << ' UNION '\n"
      code << "k << #{q2.c}.where(c).to_sql \n"
      code << "k << ') AS U'\n"
      code << "k\n"
      code.c
    end

    list(:subledger_accounts, model: :accounts, conditions: account_conditions, joins: %i[journal_entry_items], order: 'accounts.number', select: subledger_accounts_selections, group: %w[accounts.number accounts.name accounts.description accounts.id account_currency], count: 'DISTINCT accounts.number') do |t|
      t.column :number, url: { controller: :general_ledgers, account_number: 'RECORD.number'.c, current_financial_year: 'params[:current_financial_year]'.c, ledger: 'RECORD.centralizing_account&.number'.c }
      t.column :name, url: true
      t.column :description
      t.column :cumulated_absolute_debit_balance, currency: :account_currency, class: :gutter, default: ''
      t.column :cumulated_absolute_credit_balance, currency: :account_currency, class: :gutter, default: ''
    end

    list(:centralized_ledger_accounts, model: :accounts, select: [['*']], from: union_subquery, count: 'DISTINCT U.account_number', group: 'U.account_number, U.number, U.name, U.id, U.cumulated_absolute_credit_balance, U.cumulated_absolute_debit_balance, U.description, U.account_currency',order: 'U.account_number') do |t|
      t.column :account_number, url: { controller: :general_ledgers, action: :index, current_financial_year: 'params[:current_financial_year]'.c, ledger: 'RECORD.number'.c }
      t.column :name, url: true
      t.column :description
      t.column :cumulated_absolute_debit_balance, currency: :account_currency, class: :gutter, default: ''
      t.column :cumulated_absolute_credit_balance, currency: :account_currency, class: :gutter, default: ''
    end

    list(:subledger_journal_entry_items, model: :journal_entry_items, conditions: list_conditions, joins: %i[entry account journal], order: "#{JournalEntryItem.table_name}.printed_on, #{JournalEntryItem.table_name}.id") do |t|
      t.column :printed_on
      t.column :journal_name, url: { controller: :journals, id: 'RECORD.journal_id'.c }, label: :journal
      t.column :account, url: true, hidden: true
      t.column :account_number, through: :account, label_method: :number, url: { controller: :general_ledgers, account_number: 'RECORD.account.number'.c, current_financial_year: 'params[:current_financial_year]'.c, ledger: 'RECORD.account&.centralizing_account&.number'.c }, hidden: true
      t.column :account_name, through: :account, label_method: :name, url: true, hidden: true
      t.column :entry_number, url: { controller: :journal_entries, id: 'RECORD.entry_id'.c }  
      t.column :continuous_number, hidden: true
      t.column :code, through: :journal, label: :journal, hidden: true
      t.column :entry_resource_label, url: { controller: 'RECORD&.entry&.resource&.class&.model_name&.plural'.c, id: 'RECORD&.entry&.resource&.id'.c }, label: :entry_resource_label, class: 'entry-resource-label'
      t.column :name, class: 'entry-name'
      t.column :reference_number, through: :entry, hidden: true
      t.column :variant, url: true, hidden: true
      t.column :letter
      t.column :real_debit,  currency: :real_currency, hidden: true
      t.column :real_credit, currency: :real_currency, hidden: true
      t.column :debit,  currency: true, class: :gutter, default: ''
      t.column :credit, currency: true, class: :gutter, default: ''
      t.column :absolute_debit,  currency: :absolute_currency, hidden: true
      t.column :absolute_credit, currency: :absolute_currency, hidden: true
      t.column :cumulated_absolute_debit,  currency: :absolute_currency, hidden: true
      t.column :cumulated_absolute_credit, currency: :absolute_currency, hidden: true
      t.column :cumulated_absolute_debit_balance, currency: :absolute_currency, class: :gutter, default: ''
      t.column :cumulated_absolute_credit_balance, currency: :absolute_currency, class: :gutter, default: ''
    end

    def index

      ledger_label = :general_ledger.tl

      params[:ledger] ||= 'general_ledger'

      if account = Account.find_by(number: params[:ledger])
        ledger_label = :subledger_of_accounts_x.tl(account: account.name)
      end

      t3e(ledger: ledger_label)

      document_name = human_action_name.to_s
      filename = "#{human_action_name}_#{Time.zone.now.l(format: '%Y%m%d%H%M%S')}"
      respond_to do |format|
        format.html
        format.ods do
          @general_ledger = Account.ledger(params) if params[:period]
          send_data(
            to_ods(@general_ledger).bytes,
            filename: filename << '.ods'
          )
        end
        format.csv do
          @general_ledger = Account.ledger(params) if params[:period]
          csv_string = CSV.generate(headers: true) do |csv|
            to_csv(@general_ledger, csv)
          end
          send_data(csv_string, filename: filename << '.csv')
        end
        format.xcsv do
          @general_ledger = Account.ledger(params) if params[:period]
          csv_string = CSV.generate(headers: true, col_sep: ';', encoding: 'CP1252') do |csv|
            to_csv(@general_ledger, csv)
          end
          send_data(csv_string, filename: filename << '.csv')
        end
        format.odt do
          @general_ledger = Account.ledger(params) if params[:period]
          send_data to_odt(@general_ledger, document_name, filename, params).generate, type: 'application/vnd.oasis.opendocument.text', disposition: 'attachment', filename: filename << '.odt'
        end
      end
    end

    def show
      return redirect_to(backend_general_ledgers_path) unless params[:account_number] && account = Account.find_by(number: params[:account_number])

      financial_year = FinancialYear.find_by(id: params[:current_financial_year])
      financial_year ||= FinancialYear.current
      params[:period] = financial_year.started_on.to_s << '_' << financial_year.stopped_on.to_s
      params[:current_financial_year] ||= financial_year.id

      t3e(account: account.label)
      document_name = human_action_name.to_s
      filename = "#{human_action_name}_#{Time.zone.now.l(format: '%Y%m%d%H%M%S')}"

      conditions_code = '(' + self.class.list_conditions.gsub(/\s*\n\s*/, ';') + ')'

      obj = eval(conditions_code)

      @calculations = JournalEntryItem.joins(%i[entry account journal]).where(obj).pluck("COALESCE(SUM(#{JournalEntryItem.table_name}.absolute_debit), 0) AS cumulated_absolute_debit, COALESCE(SUM(#{JournalEntryItem.table_name}.absolute_credit), 0) AS cumulated_absolute_credit").first
      @calculations << @calculations[0] - @calculations[1]

      respond_to do |format|
        format.html
        format.ods do
          @general_ledger = Account.ledger(params) if params[:period]
          send_data(
            to_ods(@general_ledger).bytes,
            filename: filename << '.ods'
          )
        end
        format.csv do
          @general_ledger = Account.ledger(params) if params[:period]
          csv_string = CSV.generate(headers: true) do |csv|
            to_csv(@general_ledger, csv)
          end
          send_data(csv_string, filename: filename << '.csv')
        end
        format.xcsv do
          @general_ledger = Account.ledger(params) if params[:period]
          csv_string = CSV.generate(headers: true, col_sep: ';', encoding: 'CP1252') do |csv|
            to_csv(@general_ledger, csv)
          end
          send_data(csv_string, filename: filename << '.csv')
        end
        format.odt do
          @general_ledger = Account.ledger(params) if params[:period]
          send_data to_odt(@general_ledger, document_name, filename, params).generate, type: 'application/vnd.oasis.opendocument.text', disposition: 'attachment', filename: filename << '.odt'
        end
      end
    end

    def mask_lettered_items
      preference_name = 'backend/general_ledgers'
      preference_name << ".#{params[:context]}" if params[:context]
      preference_name << '.lettered_items.masked'
      current_user.prefer!(preference_name, params[:masked].to_s == 'true', :boolean)
      head :ok
    end

    def mask_draft_items
      preference_name = 'backend/general_ledgers'
      preference_name << ".#{params[:context]}" if params[:context]
      preference_name << '.draft_items.masked'
      current_user.prefer!(preference_name, params[:masked].to_s == 'true', :boolean)
      head :ok
    end

    protected

    def to_odt(general_ledger, document_name, filename, params)
      # TODO: add a generic template system path
      report = ODFReport::Report.new(Rails.root.join('config', 'locales', 'fra', 'reporting', 'general_ledger.odt')) do |r|
        # TODO: add a helper with generic metod to implemend header and footer

        data_filters = []
        unless params[:accounts].empty?
          data_filters << Account.human_attribute_name(:account) + ' : ' + params[:accounts]
        end

        if params[:lettering_state]
          content = []
          content << :unlettered.tl if params[:lettering_state].include?('unlettered')
          content << :partially_lettered.tl if params[:lettering_state].include?('partially_lettered')
          content << :lettered.tl if params[:lettering_state].include?('lettered')
          data_filters << :lettering_state.tl + ' : ' + content.to_sentence
        end

        if params[:states].any?
          content = []
          content << :draft.tl if params[:states].include?('draft') && params[:states]['draft'].to_i == 1
          content << :confirmed.tl if params[:states].include?('confirmed') && params[:states]['confirmed'].to_i == 1
          content << :closed.tl if params[:states].include?('closed') && params[:states]['closed'].to_i == 1
          data_filters << :journal_entries_states.tl + ' : ' + content.to_sentence
        end

        e = Entity.of_company
        company_name = e.full_name
        company_address = e.default_mail_address.coordinate

        started_on = params[:period].split('_').first if params[:period]
        stopped_on = params[:period].split('_').last if params[:period]

        r.add_field 'COMPANY_ADDRESS', company_address
        r.add_field 'DOCUMENT_NAME', document_name
        r.add_field 'FILENAME', filename
        r.add_field 'PRINTED_AT', Time.zone.now.l(format: '%d/%m/%Y %T')
        r.add_field 'STARTED_ON', started_on.to_date.strftime('%d/%m/%Y') if started_on
        r.add_field 'STOPPED_ON', stopped_on.to_date.strftime('%d/%m/%Y') if stopped_on
        r.add_field 'DATA_FILTERS', data_filters * ' | '

        r.add_section('Section1', general_ledger) do |s|
          s.add_field(:account_number, :account_number)
          s.add_field(:account_name, :account_name)
          s.add_field(:count, :count)
          s.add_field(:currency, :currency)
          s.add_field(:total_debit, :total_debit)
          s.add_field(:total_credit, :total_credit)
          s.add_field(:total_cumulated_balance) do |acc|
            acc[:total_debit] - acc[:total_credit]
          end

          s.add_table('Tableau1', :items, header: true) do |t|
            t.add_column(:entry_number) { |item| item[:entry_number] }
            t.add_column(:continuous_number) { |item| item[:continuous_number] }
            t.add_column(:printed_on) { |item| item[:printed_on] }
            t.add_column(:name) { |item| item[:name] }
            t.add_column(:variant) { |item| item[:variant] }
            t.add_column(:journal_name) { |item| item[:journal_name] }
            t.add_column(:letter) { |item| item[:letter] }
            t.add_column(:real_debit) { |item| item[:real_debit] }
            t.add_column(:real_credit) { |item| item[:real_credit] }
            t.add_column(:cumulated_balance) { |item| item[:cumulated_balance] }
          end
        end
      end
    end

    def to_ods(general_ledger)
      require 'rodf'
      output = RODF::Spreadsheet.new

      output.instance_eval do
        office_style :head, family: :cell do
          property :text, 'font-weight': :bold
          property :paragraph, 'text-align': :center
        end

        office_style :right, family: :cell do
          property :paragraph, 'text-align': :right
        end

        office_style :bold, family: :cell do
          property :text, 'font-weight': :bold
        end

        office_style :italic, family: :cell do
          property :text, 'font-style': :italic
        end

        table 'ledger' do
          row do
            cell JournalEntryItem.human_attribute_name(:account_number), style: :head
            cell JournalEntryItem.human_attribute_name(:account_name), style: :head
            cell JournalEntryItem.human_attribute_name(:entry_number), style: :head
            cell JournalEntryItem.human_attribute_name(:printed_on), style: :head
            cell JournalEntryItem.human_attribute_name(:name), style: :head
            cell JournalEntryItem.human_attribute_name(:variant), style: :head
            cell JournalEntryItem.human_attribute_name(:journal), style: :head
            cell JournalEntryItem.human_attribute_name(:letter), style: :head
            cell JournalEntry.human_attribute_name(:debit), style: :head
            cell JournalEntry.human_attribute_name(:credit), style: :head
            cell JournalEntry.human_attribute_name(:balance), style: :head
          end

          general_ledger.each do |account|
            account.each do |item|
              if item[0] == 'header'
                row do
                  cell item[1], style: :head
                  cell item[2], style: :head
                end
              elsif item[0] == 'body'
                row do
                  cell item[1]
                  cell item[2]
                  cell item[3]
                  cell item[4]
                  cell item[5]
                  cell item[6]
                  cell item[7]
                  cell item[8]
                  cell item[9]
                  cell item[10]
                  cell item[11]
                end
              elsif item[0] == 'footer'
                row do
                  cell ''
                  cell item[2]
                  cell ''
                  cell ''
                  cell ''
                  cell ''
                  cell ''
                  cell :subtotal.tl(name: item[1]).l, style: :right
                  cell item[12], style: :bold
                  cell item[13], style: :bold
                end
              end
            end
          end
        end
      end
      output
    end
  end
end
