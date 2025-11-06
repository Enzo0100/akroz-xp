#!/usr/bin/env ruby
# Script para habilitar todas as features em instalações self-hosted do Chatwoot
# Uso: bundle exec rails runner script/enable_all_features.rb

require_relative '../config/environment'

def enable_all_features
  puts "=== Chatwoot - Habilitando Todas as Features ==="
  puts "Ambiente: #{Rails.env}"
  puts "Cloud: #{ChatwootApp.chatwoot_cloud? ? 'SIM' : 'NÃO (Self-Hosted)'}"
  puts ""
  
  # Carregar lista de features do arquivo YAML
  features_file = Rails.root.join('config/features.yml')
  features_list = YAML.safe_load(File.read(features_file))
  
  # Filtrar apenas features não deprecated
  active_features = features_list.reject { |f| f['deprecated'] }
  
  puts "Total de features encontradas: #{features_list.count}"
  puts "Features ativas (não deprecated): #{active_features.count}"
  puts ""
  
  # Listar todas as contas
  accounts = Account.all
  puts "Contas encontradas: #{accounts.count}"
  puts ""
  
  accounts.each_with_index do |account, index|
    puts "Processando conta ##{index + 1}: #{account.name} (ID: #{account.id})"
    
    # Habilitar todas as features ativas
    feature_names = active_features.map { |f| f['name'] }
    
    puts "  Habilitando #{feature_names.count} features..."
    
    # Usar enable_features! para salvar automaticamente
    account.enable_features!(*feature_names)
    
    # Verificar quantas features foram habilitadas
    enabled_count = account.enabled_features.count
    puts "  ✅ Features habilitadas: #{enabled_count}/#{feature_names.count}"
    
    # Listar features premium habilitadas
    premium_features = active_features.select { |f| f['premium'] }.map { |f| f['name'] }
    enabled_premium = account.enabled_features.select { |name, enabled| enabled && premium_features.include?(name) }
    
    puts "  ⭐ Features premium habilitadas: #{enabled_premium.count}/#{premium_features.count}"
    
    if enabled_premium.any?
      puts "  📋 Features premium ativas:"
      enabled_premium.each_key { |feature| puts "    - #{feature}" }
    end
    
    puts ""
  end
  
  puts "✅ Processo concluído!"
  puts "Todas as features foram habilitadas em #{accounts.count} conta(s)"
end

# Executar apenas se não for ambiente de produção ou se for self-hosted
if Rails.env.production? && ChatwootApp.chatwoot_cloud?
  puts "❌ ATENÇÃO: Este script não pode ser executado em ambiente Cloud de produção!"
  puts "   Este script é apenas para instalações self-hosted."
else
  enable_all_features
end