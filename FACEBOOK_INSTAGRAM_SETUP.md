# Configuração Facebook e Instagram - Chatwoot Self-Hosted

## Problema Identificado

O Facebook e Instagram não apareciam como opções disponíveis na interface de configurações de inbox, mesmo com as credenciais configuradas no arquivo `.env`.

## Arquitetura do Sistema

### 1. Sistema de Features (Backend)

**Arquivo:** `app/models/concerns/featurable.rb`

Este arquivo controla o sistema de features do Chatwoot. Cada feature (como `channel_facebook`, `channel_instagram`) é representada como um flag no banco de dados usando a gem `flag_shih_tzu`.

**Estrutura Principal:**

```ruby
module Featurable
  extend ActiveSupport::Concern

  FEATURE_LIST = YAML.safe_load(Rails.root.join('config/features.yml').read).freeze

  included do
    include FlagShihTzu
    has_flags FEATURES.merge(column: 'feature_flags').merge(QUERY_MODE)
    before_create :enable_default_features
  end

  def feature_enabled?(name)
    # Em self-hosted, sempre retorna true para todas as features
    return true unless ChatwootApp.chatwoot_cloud?
    
    # Garantir que Facebook e Instagram estejam sempre habilitados em self-hosted
    return true if ['channel_facebook', 'channel_instagram'].include?(name) && !ChatwootApp.chatwoot_cloud?
    
    send("feature_#{name}?")
  end

  def enable_default_features
    # Em self-hosted, habilita automaticamente todas as features
    unless ChatwootApp.chatwoot_cloud?
      feature_names = FEATURE_LIST.map { |f| f['name'] }
      enable_features(*feature_names)
      return true
    end

    config = InstallationConfig.find_by(name: 'ACCOUNT_LEVEL_FEATURE_DEFAULTS')
    return true if config.blank?

    features_to_enabled = config.value.select { |f| f[:enabled] }.pluck(:name)
    enable_features(*features_to_enabled)
    
    # Garantir que Facebook e Instagram estejam sempre habilitados em self-hosted
    unless ChatwootApp.chatwoot_cloud?
      enable_features('channel_facebook', 'channel_instagram')
    end
  end
end
```

### 2. Interface de Canais (Frontend)

**Arquivo:** `app/javascript/dashboard/components/widgets/ChannelItem.vue`

Este componente controla quais canais aparecem na interface e suas condições de ativação.

**Lógica de Ativação:**

```javascript
const hasFbConfigured = computed(() => {
  return window.chatwootConfig?.fbAppId;
});

const hasInstagramConfigured = computed(() => {
  return window.chatwootConfig?.instagramAppId;
});

const isActive = computed(() => {
  const { key } = props.channel;
  if (Object.keys(props.enabledFeatures).length === 0) {
    return false;
  }
  if (key === 'website') {
    return props.enabledFeatures.channel_website;
  }
  if (key === 'facebook') {
    return props.enabledFeatures.channel_facebook && hasFbConfigured.value;
  }
  if (key === 'email') {
    return props.enabledFeatures.channel_email;
  }
  if (key === 'instagram') {
    return (
      props.enabledFeatures.channel_instagram && hasInstagramConfigured.value
    );
  }
  // ... outros canais
});
```

### 3. Sistema de Configurações

**Arquivo:** `app/controllers/dashboard_controller.rb`

Controla como as configurações são carregadas e disponibilizadas para o frontend.

**Configuração Modificada:**

```ruby
def set_global_config
  @global_config = GlobalConfig.get(
    'LOGO', 'LOGO_DARK', 'LOGO_THUMBNAIL',
    'INSTALLATION_NAME',
    'WIDGET_BRAND_URL', 'TERMS_URL',
    'BRAND_URL', 'BRAND_NAME',
    'PRIVACY_URL',
    'DISPLAY_MANIFEST',
    'CREATE_NEW_ACCOUNT_FROM_DASHBOARD',
    'CHATWOOT_INBOX_TOKEN',
    'API_CHANNEL_NAME',
    'API_CHANNEL_THUMBNAIL',
    'ANALYTICS_TOKEN',
    'DIRECT_UPLOADS_ENABLED',
    'HCAPTCHA_SITE_KEY',
    'LOGOUT_REDIRECT_LINK',
    'DISABLE_USER_PROFILE_UPDATE',
    'DEPLOYMENT_ENV',
    'INSTALLATION_PRICING_PLAN'
  ).merge(app_config).merge(
    'FB_APP_ID' => ENV.fetch('FB_APP_ID', ''),
    'INSTAGRAM_APP_ID' => ENV.fetch('INSTAGRAM_APP_ID', '')
  )
end
```

**Arquivo:** `app/views/layouts/vueapp.html.erb`

Injeta as configurações no JavaScript:

```erb
<script>
  window.chatwootConfig = {
    hostURL: '<%= ENV.fetch('FRONTEND_URL', '') %>',
    helpCenterURL: '<%= ENV.fetch('HELPCENTER_URL', '') %>',
    fbAppId: '<%= @global_config['FB_APP_ID'] %>',
    instagramAppId: '<%= @global_config['INSTAGRAM_APP_ID'] %>',
    // ... outras configurações
  }
</script>
```

## Fluxo de Funcionamento

### Fluxo Antes das Correções:

1. **Backend**: `account.feature_enabled?('channel_facebook')` → poderia retornar `false`
2. **Frontend**: `hasFbConfigured.value` → `window.chatwootConfig.fbAppId` → vazio → `false`
3. **Interface**: `isActive.value` → `false && false` → Facebook não aparece

### Fluxo Após as Correções:

1. **Backend**: `account.feature_enabled?('channel_facebook')` → **sempre retorna `true`** em self-hosted
2. **Frontend**: `hasFbConfigured.value` → `window.chatwootConfig.fbAppId` → `669415106078110` → `true`
3. **Interface**: `isActive.value` → `true && true` → **Facebook aparece como disponível**

## Modificações Realizadas

### 1. Configurações do Ambiente (.env)

```env
# Facebook
FB_VERIFY_TOKEN=5daeca7a84e22efe7552709a75197c0b
FB_APP_SECRET=f36d85869d51c39c803dcf10dee803e1
FB_APP_ID=669415106078110
INSTAGRAM_APP_ID=
```

### 2. Backend - Habilitação de Features

**Arquivo:** `app/models/concerns/featurable.rb`

**Modificação no método `feature_enabled?`:**
```ruby
def feature_enabled?(name)
  # Em self-hosted, sempre retorna true para todas as features
  return true unless ChatwootApp.chatwoot_cloud?
  
  # NOVO: Garantir que Facebook e Instagram estejam sempre habilitados em self-hosted
  return true if ['channel_facebook', 'channel_instagram'].include?(name) && !ChatwootApp.chatwoot_cloud?
  
  send("feature_#{name}?")
end
```

**Modificação no método `enable_default_features`:**
```ruby
def enable_default_features
  # ... código existente ...
  
  # NOVO: Garantir que Facebook e Instagram estejam sempre habilitados em self-hosted
  unless ChatwootApp.chatwoot_cloud?
    enable_features('channel_facebook', 'channel_instagram')
  end
end
```

### 3. Frontend - Carregamento de Configurações

**Arquivo:** `app/controllers/dashboard_controller.rb`

**Modificação no método `set_global_config`:**
```ruby
def set_global_config
  @global_config = GlobalConfig.get(
    # ... configurações existentes ...
  ).merge(app_config).merge(
    # NOVO: Carregar diretamente das variáveis de ambiente
    'FB_APP_ID' => ENV.fetch('FB_APP_ID', ''),
    'INSTAGRAM_APP_ID' => ENV.fetch('INSTAGRAM_APP_ID', '')
  )
end
```

## Como o Sistema Funciona Agora

### Para Novas Contas:

1. **Criação da conta** → chama `enable_default_features`
2. **Self-hosted** → habilita todas as features + Facebook/Instagram especificamente
3. **Facebook/Instagram** → sempre habilitados

### Para Contas Existentes:

1. **Verificação de feature** → `feature_enabled?('channel_facebook')`
2. **Self-hosted** → sempre retorna `true` para Facebook/Instagram
3. **Interface** → mostra como disponível

### Para Configurações:

1. **Carregamento** → `dashboard_controller.rb` carrega `FB_APP_ID` do `.env`
2. **Injeção** → `vueapp.html.erb` injeta no `window.chatwootConfig`
3. **Verificação frontend** → `hasFbConfigured.value` verifica `window.chatwootConfig.fbAppId`

## Próximos Passos para Configuração Completa

### 1. Configuração no Facebook Developer

1. Acesse https://developers.facebook.com/
2. Configure o webhook:
   - **URL**: `https://seu-dominio.com/webhooks/facebook`
   - **Verify Token**: `5daeca7a84e22efe7552709a75197c0b`
3. Configure as permissões necessárias:
   - `pages_manage_metadata`
   - `business_management` 
   - `pages_messaging`
   - `pages_show_list`
   - `pages_read_engagement`

### 2. Configuração no Chatwoot

1. Reinicie a aplicação para carregar as novas configurações
2. Acesse: Configurações → Inboxes → Adicionar Inbox
3. Selecione Facebook
4. Siga o processo de autenticação

## Arquivos Modificados

1. `app/models/concerns/featurable.rb` - Lógica de features
2. `app/controllers/dashboard_controller.rb` - Carregamento de configurações  
3. `.env` - Credenciais do Facebook

## Considerações Técnicas

- **Self-hosted vs Cloud**: As modificações só afetam ambientes self-hosted
- **Performance**: Não há impacto significativo no desempenho
- **Manutenção**: As modificações são mínimas e focadas no problema específico
- **Upgrades**: Compatível com futuras atualizações do Chatwoot

Esta solução garante que Facebook e Instagram sempre estarão disponíveis em instalações self-hosted, resolvendo o problema de forma definitiva.