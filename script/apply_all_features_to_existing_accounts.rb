#!/usr/bin/env ruby
# Script para aplicar todas as features em contas existentes
# Uso: bundle exec rails runner script/apply_all_features_to_existing_accounts.rb

require_relative '../config/environment'

def apply_all_features_to_existing_accounts
  puts "=== Chatwoot - Aplicando Todas as Features em Contas Existentes ==="
  puts "Ambiente: #{Rails.env}"
  puts "Cloud: #{ChatwootApp.chatwoot_cloud? ? 'SIM' : 'NÃO (Self-Hosted)'}"
  puts ""
  
  # Carregar lista de features
  features_file = Rails.root.join('config/features.yml')
  features_list = YAML.safe_load(File.read(features_file))
  
  # Filtrar apenas features não deprecated
  active_features = features_list.reject { |f| f['deprecated'] }
  feature_names = active_features.map { |f| f['name'] }
  
  puts "Total de features ativas: #{feature_names.count}"
  puts ""
  
  # Processar todas as contas
  accounts = Account.all
  puts "Contas encontradas: #{accounts.count}"
  puts ""
  
  accounts.each_with_index do |account, index|
    puts "Processando conta ##{index + 1}: #{account.name} (ID: #{account.id})"
    
    # Verificar features atuais
    current_enabled = account.enabled_features.keys
    puts "  Features atuais: #{current_enabled.count}"
    
    # Habilitar todas as features
    account.enable_features!(*feature_names)
    
    # Verificar resultado
    new_enabled = account.enabled_features.keys
    puts "  ✅ Features após aplicação: #{new_enabled.count}"
    puts "  📈 Features adicionadas: #{new_enabled.count - current_enabled.count}"
    
    # Listar features premium
    premium_features = active_features.select { |f| f['premium'] }.map { |f| f['name'] }
    enabled_premium = new_enabled & premium_features
    puts "  ⭐ Features premium habilitadas: #{enabled_premium.count}/#{premium_features.count}"
    
    puts ""
  end
  
  puts "✅ Processo concluído!"
  puts "Todas as features foram aplicadas em #{accounts.count} conta(s)"
end

# Executar apenas se não for ambiente de produção ou se for self-hosted
if Rails.env.production? && ChatwootApp.chatwoot_cloud?
  puts "❌ ATENÇÃO: Este script não pode ser executado em ambiente Cloud de produção!"
  puts "   Este script é apenas para instalações self-hosted."
else
  apply_all_features_to_existing_accounts
end