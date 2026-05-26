#!/usr/bin/env ruby

# 🚀 Dchat - Script PERMANENTE para desbloquear o Chatwoot Enterprise
# Execute com: wget -qO- https://raw.githubusercontent.com/LuizBranco-ClickHype/Dchat/main/unlock_permanent.rb | bundle exec rails runner -

require 'fileutils'

puts "🚀 === Dchat - Desbloqueio PERMANENTE do Chatwoot Enterprise ==="
puts ""

# SQL para criar trigger permanente
sql_trigger = <<-SQL
-- Função que força valores enterprise
CREATE OR REPLACE FUNCTION force_enterprise_installation_configs()
RETURNS TRIGGER AS $$
BEGIN
    IF NEW.name = 'INSTALLATION_PRICING_PLAN' THEN
        NEW.serialized_value = '{"value":"enterprise"}'::jsonb;\n');
        NEW.locked = true;
    END IF;

    IF NEW.name = 'INSTALLATION_PRICING_PLAN_QUANTITY' THEN
       NEW.serialized_value = '{"value":9999999}'::jsonb;
        NEW.locked = true;
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Remove trigger anterior se existir
DROP TRIGGER IF EXISTS trg_force_enterprise_configs ON installation_configs;

-- Cria trigger
CREATE TRIGGER trg_force_enterprise_configs
BEFORE INSERT OR UPDATE ON installation_configs
FOR EACH ROW
EXECUTE FUNCTION force_enterprise_installation_configs();
SQL

begin
  puts "📊 Aplicando trigger permanente no PostgreSQL..."

  # Executa o SQL diretamente
  ActiveRecord::Base.connection.execute(sql_trigger)

  puts "✅ Trigger criado com sucesso!"
  puts "   • Função: force_enterprise_installation_configs()"
  puts "   • Trigger: trg_force_enterprise_configs"
  puts ""

rescue => e
  puts "❌ Erro ao criar trigger: #{e.message}"
  puts "   Tentando método alternativo..."
  puts ""
end

# Atualiza registros atuais
begin
  puts "💾 Atualizando configurações no banco de dados..."

  plan = InstallationConfig.find_or_initialize_by(name: 'INSTALLATION_PRICING_PLAN')
  plan.serialized_value = { value: 'enterprise' }
  plan.locked = true
  plan.save!
  puts "✅ Plano enterprise configurado e bloqueado"

  quantity = InstallationConfig.find_or_initialize_by(name: 'INSTALLATION_PRICING_PLAN_QUANTITY')
  quantity.serialized_value = { value: 9_999_999 }
  quantity.locked = true
  quantity.save!
  puts "✅ Quantidade de usuários configurada e bloqueada (9.999.999)"
  puts ""

rescue => e
  puts "❌ Erro nas configurações do banco: #{e.message}"
  puts ""
end

# Limpa cache Redis
begin
  if defined?(Redis::Alfred)
    Redis::Alfred.delete(Redis::Alfred::CHATWOOT_INSTALLATION_CONFIG_RESET_WARNING)
    puts '✅ Flag de alerta premium removida do Redis'
  end
rescue => e
  puts "⚠️  Erro ao limpar Redis: #{e.message}"
end

# Atualiza fallback em lib/chatwoot_hub.rb
begin
  possible_paths = [
    '/app/lib/chatwoot_hub.rb',
    '/chatwoot/lib/chatwoot_hub.rb',
    File.join(Rails.root, 'lib', 'chatwoot_hub.rb'),
    './lib/chatwoot_hub.rb'
  ]

  hub_file = possible_paths.find { |path| File.exist?(path) }

  if hub_file
    puts "📁 Arquivo encontrado: #{hub_file}"

    # Backup
    backup_file = "#{hub_file}.backup.#{Time.now.strftime('%Y%m%d_%H%M%S')}"
    FileUtils.cp(hub_file, backup_file)
    puts "💾 Backup: #{backup_file}"

    # Ler e atualizar conteúdo
    content = File.read(hub_file)
    original = content.dup

    # Atualiza fallbacks
    content.gsub!(
      /(InstallationConfig\.find_by\(name:\s*['"]INSTALLATION_PRICING_PLAN['"]\)&?\.value\s*\|\|\s*)['"]community['"]/,
      "\\1'enterprise'"
    )

    content.gsub!(
      /(InstallationConfig\.find_by\(name:\s*['"]INSTALLATION_PRICING_PLAN_QUANTITY['"]\)&?\.value\s*\|\|\s*)0/,
      "\\19999999"
    )

    if content != original
      File.write(hub_file, content)
      puts "✅ Fallbacks atualizados em #{hub_file}"
    else
      puts "ℹ️  Arquivo já estava atualizado"
    end
    puts ""
  end

rescue => e
  puts "⚠️  Erro ao atualizar arquivo: #{e.message}"
  puts ""
end

# Verifica configurações finais
begin
  puts "🔍 Verificando configurações aplicadas:"

  configs = InstallationConfig.where(name: ['INSTALLATION_PRICING_PLAN', 'INSTALLATION_PRICING_PLAN_QUANTITY'])

  configs.each do |config|
    puts "   • #{config.name}: #{config.value} (locked: #{config.locked || false})"
  end

  # Verifica se o trigger existe
  trigger_check = ActiveRecord::Base.connection.execute(
    "SELECT EXISTS (SELECT 1 FROM pg_trigger WHERE tgname = 'trg_force_enterprise_configs') as exists"
  ).first

  if trigger_check && trigger_check['exists']
    puts "   • Trigger PostgreSQL: ✅ ATIVO"
  else
    puts "   • Trigger PostgreSQL: ⚠️  Não detectado"
  end

rescue => e
  puts "⚠️  Erro ao verificar: #{e.message}"
end

puts ""
puts "🎉 === Desbloqueio PERMANENTE concluído ==="
puts ""
puts "🔒 PROTEÇÃO ATIVA:"
puts "   • Trigger PostgreSQL monitora e força valores enterprise"
puts "   • Qualquer tentativa de alterar será revertida automaticamente"
puts "   • Configurações marcadas como 'locked'"
puts ""
puts "🔄 Reinicie o container para aplicar todas as mudanças"
puts "🌟 Dchat - Educational Project"
puts ""
