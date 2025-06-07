# 🖥️ BCC-Farming v2.5.0 NUI System Guide

## 📋 **Como Ver as Informações das Plantas**

### 🎯 **Método 1: Detecção Automática por Proximidade**

#### Como Funciona:
1. **Plante uma semente** (ex: seed_apple, seed_corn)
2. **Aproxime-se da planta** (raio de 3 metros)
3. **A NUI aparecerá automaticamente** mostrando as informações

#### Sistema de Detecção:
- **Raio de Detecção**: 3 metros
- **Atualização**: A cada 1 segundo
- **Props Detectados**: Todos os estágios (stage1, stage2, stage3)
- **Multi-plantas**: Mostra a planta mais próxima

---

### 🎯 **Método 2: Comando de Teste (Para Desenvolvedores)**

#### Comando Básico:
```bash
/test-plant-nui
```
- Mostra uma NUI de teste com dados simulados
- Útil para testar o visual sem precisar plantar

#### Comando para Esconder:
```bash
/hide-plant-nui
```
- Esconde a NUI manualmente

---

## 📊 **Informações Mostradas na NUI**

### 🌱 **Informações Básicas:**
- **Nome da Planta**: Ex: "Maçã", "Milho", "Cereja"
- **Estágio Atual**: Stage 1 (Seedling), Stage 2 (Young Plant), Stage 3 (Mature Plant)
- **Progresso Geral**: 0-100% do crescimento total

### 📈 **Barras de Progresso:**
1. **Growth Progress**: Crescimento geral da planta (0-100%)
2. **Stage Progress**: Progresso dentro do estágio atual
3. **Watering Progress**: Eficiência de irrigação atual

### 💧 **Sistema de Irrigação v2.5.0:**
- **Contagem de Regas**: Ex: "2/3 waterings (67%)"
- **Eficiência**: Baseada em quantas vezes foi regada vs. necessário
- **Status**: Indica se precisa de mais água

### 🌿 **Sistema de Fertilizante v2.5.0:**
- **Status**: Fertilizado, Necessário, Opcional
- **Tipo**: Base fertilizer, Enhanced, etc.
- **Indicador Visual**: ✅ Fertilizado, ⚠️ Necessário, ➖ Opcional

### ⏰ **Tempo e Status:**
- **Tempo Restante**: Countdown até estar pronto
- **Status Geral**: Growing, Ready, Needs Attention
- **Recompensa Estimada**: Baseada na eficiência atual

---

## 🎮 **Como Testar o Sistema NUI**

### 📋 **Passo a Passo Completo:**

#### 1. **Preparar Items**
```bash
/give [your_id] seed_apple 1
/give [your_id] fertilizer 1     # (opcional)
```

#### 2. **Plantar**
- Use seed_apple no inventário
- Aguarde animação de plantio (16s)
- Escolha fertilizar ou não

#### 3. **Ver NUI**
- Aproxime-se da planta plantada
- A NUI deve aparecer automaticamente
- Veja as informações da planta em tempo real

#### 4. **Testar Irrigação (Opcional)**
```bash
/give [your_id] wateringcan 1
```
- Use o balde de água na planta
- Veja a eficiência de irrigação mudar na NUI

---

## 🔧 **Funcionalidades da NUI**

### ✅ **O que Funciona:**
- **Detecção automática** de plantas próximas
- **Informações em tempo real** das plantas v2.5.0
- **Barras de progresso** animadas
- **Countdown de tempo** atualizado
- **Status visual** com ícones
- **Sistema multi-stage** compatível
- **Cálculos de eficiência** baseados em v2.5.0

### 🎨 **Interface Visual:**
- **Design limpo** integrado com npp_farmstats
- **Animações suaves** de entrada/saída
- **Cores dinâmicas** baseadas no status
- **Ícones FontAwesome** para melhor UX
- **Layout responsivo** com informações claras

---

## 🐛 **Troubleshooting**

### ❌ **NUI Não Aparece:**
1. Verifique se você está próximo da planta (< 3 metros)
2. Certifique-se que a planta foi plantada corretamente
3. Teste com `/test-plant-nui` para verificar se a NUI funciona

### ❌ **Informações Incorretas:**
1. Dados vêm diretamente do database v2.5.0
2. Plante uma nova seed para testar com dados atualizados
3. Verifique se a migração do database foi aplicada

### ❌ **Performance Issues:**
1. Sistema otimizado para verificar proximidade a cada 1s
2. NUI só ativa quando necessário
3. Detecção automática é pausada quando não há NUI ativa

---

## 🚀 **Comandos Úteis Para Teste:**

### Comandos de Planta:
```bash
/give [your_id] seed_apple 1
/give [your_id] seed_corn 1  
/give [your_id] seed_cherry 1
```

### Comandos de Fertilizante:
```bash
/give [your_id] fertilizer 1
/give [your_id] fertilizer1 1
/give [your_id] fertilizer2 1
```

### Comandos de Irrigação:
```bash
/give [your_id] wateringcan 1
```

### Comandos de NUI:
```bash
/test-plant-nui          # Mostra NUI de teste
/hide-plant-nui          # Esconde NUI
```

### Comandos de Sistema:
```bash
/farming-test-simple     # Testa sistema completo
/farming-health-check    # Status do sistema
```

---

## 🎯 **Resultado Esperado:**

Quando você se aproximar de uma planta plantada, você deve ver:

1. **💻 Painel NUI** aparece no lado direito da tela
2. **🌱 Nome da planta** e estágio atual
3. **📊 Barras de progresso** para crescimento, irrigação, fertilizante
4. **⏰ Countdown** até estar pronto para colheita
5. **🎯 Status visual** indicando o que a planta precisa
6. **📈 Recompensa estimada** baseada na eficiência atual

**A NUI deve funcionar automaticamente sem comandos! Basta plantar e se aproximar! 🌱**