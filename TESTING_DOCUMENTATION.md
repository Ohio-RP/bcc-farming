# BCC-Farming v2.5.0 Testing Documentation

## Comprehensive Testing Suite for Enhanced Farming System

This documentation covers the complete testing framework for BCC-Farming v2.5.0, including validation, performance testing, and production readiness checks.

---

## 🎯 Testing Overview

### Testing Philosophy
The BCC-Farming v2.5.0 testing suite follows a comprehensive approach:

- **🔒 Critical Path Testing**: Database migration and configuration validation
- **⚡ Performance Benchmarking**: System performance under various loads
- **🔧 Functional Validation**: All features and exports working correctly
- **🚀 Production Readiness**: Comprehensive checks before deployment

### Test Categories

1. **Configuration Validation** - Plant configs, compatibility, optimization
2. **Migration Validation** - Database schema and data migration verification
3. **System Tests** - Functional testing of all components
4. **Performance Tests** - Load testing and performance benchmarking

---

## 📁 Test Files Structure

```
bcc-farming/testing/
├── test_runner.lua              # Main test orchestrator
├── test_suite_v2.5.0.lua       # Comprehensive system tests
├── migration_validator.lua      # Database migration validation
├── performance_tests.lua       # Performance and load testing
├── config_validator.lua        # Configuration validation
└── TESTING_DOCUMENTATION.md    # This file
```

---

## 🚀 Quick Start Guide

### 1. Basic Commands

```bash
# Run all tests (comprehensive)
/farming-test-full

# Quick validation (critical tests only)
/farming-test-quick

# Production readiness check
/farming-test-production

# Pre-flight checks
/farming-test-preflight
```

### 2. Individual Test Categories

```bash
# Configuration tests
/farming-validate-config

# Database migration tests
/farming-validate-migration

# System functionality tests
/farming-test-all

# Performance tests
/farming-perf-all
```

### 3. Specific Component Tests

```bash
# Database schema validation
/farming-validate-schema

# Export function tests
/farming-test-exports

# Performance benchmarks
/farming-perf-exports
/farming-perf-calc
/farming-perf-db
```

---

## 🔧 Configuration Validation

### Purpose
Validates plant configurations for v2.5.0 compatibility and optimal setup.

### What It Checks

#### ✅ Required Fields
- `seedName` - Seed item identifier
- `plantName` - Display name for the plant
- `rewards` - Reward configuration

#### 🌱 v2.5.0 Features
- `plantProps` - Multi-stage prop system
- `waterTimes` - Multi-watering requirements
- `requiresBaseFertilizer` - Base fertilizer system
- `baseFertilizerItem` - Fertilizer item specification

#### 🔄 Compatibility
- Backward compatibility with legacy configurations
- Mixed system detection and recommendations
- Optimization suggestions

### Example Output

```
[12:34:56][CONFIG][PASS] Plants table found with 5 plant configurations
[12:34:56][CONFIG][PASS] Corn has valid stage1 prop
[12:34:56][CONFIG][WARN] Wheat using legacy prop system
[12:34:56][CONFIG][PASS] All plants are v2.5.0 compatible!
```

### Configuration Best Practices

```lua
-- ✅ Good v2.5.0 Configuration
{
    seedName = 'corn_seed',
    plantName = 'Corn',
    plantProps = {
        stage1 = 'p_corn_seedling',
        stage2 = 'p_corn_young',
        stage3 = 'p_corn_mature'
    },
    waterTimes = 3,
    requiresBaseFertilizer = true,
    baseFertilizerItem = 'fertilizer',
    rewards = {
        amount = 10,
        items = {{item = 'corn', count = 1}}
    }
}

-- ⚠️ Legacy Configuration (still works)
{
    seedName = 'wheat_seed',
    plantName = 'Wheat',
    plantProp = 'p_wheat_01',
    rewards = {
        amount = 8,
        items = {{item = 'wheat', count = 1}}
    }
}
```

---

## 💾 Migration Validation

### Purpose
Ensures successful database migration from v2.4.2 to v2.5.0 without data loss.

### Validation Checklist

#### 📋 Schema Validation
- ✅ New columns exist with correct data types
- ✅ Helper tables created successfully
- ✅ Indexes applied for performance
- ✅ Legacy columns preserved for compatibility

#### 📊 Data Validation
- ✅ Existing plant data preserved
- ✅ Default values applied to new columns
- ✅ Data ranges within valid bounds
- ✅ Legacy compatibility maintained

#### 💾 Backup Validation
- ✅ Backup tables created before migration
- ✅ Record counts match between backup and current
- ✅ Rollback capability verified

#### ⚙️ Stored Procedures
- ✅ Growth calculation procedures
- ✅ Watering efficiency functions
- ✅ NUI status procedures

### Migration Safety

```sql
-- Automatic backup creation
CREATE TABLE bcc_farming_backup_pre_v250 AS SELECT * FROM bcc_farming;

-- Safe migration with validation
ALTER TABLE bcc_farming ADD COLUMN growth_stage INT DEFAULT 1;
ALTER TABLE bcc_farming ADD COLUMN growth_progress DECIMAL(5,2) DEFAULT 0.00;

-- Rollback capability preserved
-- All legacy columns maintained for compatibility
```

### Validation Results

```
[12:34:56][MIGRATION][PASS] Column 'growth_stage' exists with correct type
[12:34:56][MIGRATION][PASS] Helper table 'bcc_farming_growth_stages' created successfully
[12:34:56][MIGRATION][PASS] No NULL values found in 'growth_progress' column
[12:34:56][MIGRATION][PASS] All 'water_count' values within valid range (0-50)
[12:34:56][MIGRATION][PASS] System appears ready for rollback if needed
```

---

## ⚙️ System Functionality Tests

### Purpose
Comprehensive testing of all BCC-Farming v2.5.0 features and components.

### Test Coverage

#### 🗄️ Database Tests
- Schema validation
- Helper table functionality
- Default value verification
- Data consistency checks

#### ⚙️ Configuration Tests
- Plant configuration loading
- Backward compatibility
- v2.5.0 feature detection

#### 🧮 Calculation Tests
- Growth stage determination
- Reward calculations
- Watering validation
- Fertilizer effects

#### 📤 Export Function Tests
- All 13 export functions
- Enhanced v2.5.0 data structures
- Error handling
- Response validation

#### 🎨 NUI System Tests
- Configuration validation
- File structure checks
- Integration points

#### 🔗 Integration Tests
- Client-server communication
- Database consistency
- Configuration compatibility

### Example Test Results

```
[12:34:56][CALCULATIONS][PASS] Progress 15% = Stage 1
[12:34:56][CALCULATIONS][PASS] Progress 85% = Stage 3
[12:34:56][CALCULATIONS][PASS] Full efficiency = full reward
[12:34:56][CALCULATIONS][PASS] Insufficient watering reduces reward
[12:34:56][EXPORTS][PASS] Export GetGlobalPlantCount returns result
[12:34:56][EXPORTS][PASS] GetGrowthStageDistribution includes stages
```

---

## ⚡ Performance Testing

### Purpose
Benchmarks system performance and identifies potential bottlenecks.

### Performance Metrics

#### 📤 Export Performance
- Response times for all export functions
- Load testing with concurrent requests
- Memory usage tracking
- CPU utilization monitoring

#### 🧮 Calculation Performance
- Growth stage calculations
- Reward calculations
- Watering validation
- Bulk operation benchmarks

#### 🗄️ Database Performance
- Query execution times
- Complex aggregation performance
- Index effectiveness
- Concurrent access handling

#### 💾 Memory Management
- Memory usage before/after operations
- Garbage collection effectiveness
- Memory leak detection
- Resource cleanup validation

### Performance Benchmarks

```
[12:34:56][PERF][PASS] GetFarmingOverview completed in 45ms (< 1000ms)
[12:34:56][PERF][PASS] Growth Stage Calculation (100 calls): avg 12ms, max 18ms
[12:34:56][PERF][PASS] Complex Aggregation Query: avg 67ms, max 89ms
[12:34:56][PERF][PASS] Memory increase acceptable (2.3MB <= 50MB)
```

### Performance Configuration

```lua
-- Adjustable performance thresholds
PERF_CONFIG = {
    maxResponseTime = 1000,     -- Max acceptable response time (ms)
    maxMemoryUsage = 50,        -- Max memory increase (MB)
    testIterations = 100,       -- Number of test iterations
    runLoadTests = false,       -- Enable load testing
    runStressTests = false      -- Enable stress testing
}
```

---

## 🎛️ Test Runner Commands

### Main Test Commands

| Command | Description | Duration | Use Case |
|---------|-------------|----------|----------|
| `/farming-test-full` | Complete test suite | 5-10 minutes | Development validation |
| `/farming-test-quick` | Critical tests only | 1-2 minutes | Quick validation |
| `/farming-test-production` | Production readiness | 3-5 minutes | Pre-deployment check |
| `/farming-test-preflight` | Basic connectivity | 10-30 seconds | Environment check |

### Category-Specific Commands

| Command | Category | Description |
|---------|----------|-------------|
| `/farming-validate-config` | Configuration | Validate plant configurations |
| `/farming-validate-migration` | Migration | Check database migration |
| `/farming-test-exports` | System | Test export functions |
| `/farming-perf-all` | Performance | Run all performance tests |

### Diagnostic Commands

| Command | Purpose | Output |
|---------|---------|--------|
| `/farming-validate-schema` | Database schema check | Schema validation only |
| `/farming-validate-data` | Data integrity check | Data validation only |
| `/farming-perf-memory` | Memory usage test | Memory metrics only |
| `/farming-client-debug` | Client status | Client-side diagnostics |

---

## 📊 Test Results Interpretation

### Status Levels

#### ✅ PASS (Green)
- All tests completed successfully
- No issues detected
- System ready for use

#### ⚠️ WARN (Yellow)
- Tests passed with minor warnings
- Recommendations available
- Generally safe to proceed

#### ❌ FAIL (Red)
- Critical issues detected
- Requires immediate attention
- Do not deploy to production

#### ❓ UNKNOWN (Gray)
- Test could not complete
- Technical issues encountered
- Investigate and retry

### Overall Assessment

#### 🎉 EXCELLENT
- All tests pass perfectly
- Zero warnings or issues
- Optimal configuration detected
- Ready for production deployment

#### 🟢 GOOD
- All tests pass with minor warnings
- No critical issues
- Review recommendations
- Safe for production with monitoring

#### 🟡 ACCEPTABLE
- Some non-critical tests failed
- Core functionality intact
- Consider fixing issues
- May proceed with caution

#### 🔴 CRITICAL
- Critical issues detected
- System may not function properly
- Immediate attention required
- Do not deploy to production

---

## 🛠️ Troubleshooting

### Common Issues

#### Database Connection Failed
```
[PREFLIGHT][FAIL] Database connectivity check failed
```
**Solution**: Verify MySQL server is running and connection settings are correct.

#### Migration Not Applied
```
[MIGRATION][FAIL] Required column 'growth_stage' is missing
```
**Solution**: Run the database migration script: `database_migration_v2.sql`

#### Configuration Invalid
```
[CONFIG][FAIL] Corn missing required field 'plantName'
```
**Solution**: Add missing fields to plant configuration in `Plants` table.

#### Performance Issues
```
[PERF][FAIL] GetFarmingOverview (avg 1250ms > 1000ms)
```
**Solution**: Check database indexes, optimize queries, or increase performance thresholds.

### Debug Information

#### Enable Verbose Logging
```lua
-- In test configuration
TEST_CONFIG.logLevel = 'verbose'
PERF_CONFIG.logDetailedResults = true
```

#### Check System Status
```bash
/farming-client-debug     # Client-side status
/farming-status          # Plant status
/farming-nui-toggle      # NUI testing
```

#### Database Diagnostics
```sql
-- Check table structure
DESCRIBE bcc_farming;

-- Verify data migration
SELECT COUNT(*), AVG(growth_progress), AVG(water_count) FROM bcc_farming;

-- Check indexes
SHOW INDEX FROM bcc_farming;
```

---

## 🚀 Production Deployment Checklist

### Pre-Deployment (Required)

- [ ] ✅ Run `/farming-test-production` - Must pass
- [ ] ✅ Database migration completed successfully
- [ ] ✅ Configuration validation passed
- [ ] ✅ No critical issues detected
- [ ] ✅ Backup created and verified

### Pre-Deployment (Recommended)

- [ ] 🔍 Performance tests completed
- [ ] 📋 Warnings reviewed and addressed
- [ ] 🎛️ NUI system tested with npp_farmstats
- [ ] 📊 Export functions validated
- [ ] 🔄 Client-server communication verified

### Post-Deployment

- [ ] 🔍 Monitor server performance
- [ ] 📊 Verify export functions in production
- [ ] 🎨 Test NUI system with players
- [ ] 📈 Monitor database performance
- [ ] 🐛 Watch for error logs

---

## 📈 Continuous Testing

### Regular Testing Schedule

#### Daily (Automated)
- Basic connectivity checks
- Configuration validation
- Quick functionality tests

#### Weekly (Manual)
- Full test suite execution
- Performance benchmarking
- Database health checks

#### Before Updates
- Complete migration validation
- Compatibility testing
- Performance regression testing

#### After Updates
- Full system validation
- Production readiness check
- Performance monitoring

### Monitoring Integration

```lua
-- Example monitoring integration
RegisterNetEvent('bcc-farming:MonitoringCheck', function()
    local results = TestRunner.RunQuickValidation()
    TriggerEvent('monitoring:report', 'bcc-farming', results.overallStatus)
end)
```

---

## 🤝 Contributing to Tests

### Adding New Tests

1. **Create test function** in appropriate test file
2. **Add validation logic** with proper error handling
3. **Include performance benchmarks** if applicable
4. **Update test runner** to include new test
5. **Document test purpose** and expected results

### Test Development Guidelines

- Use `Assert()` function for validation
- Include descriptive error messages
- Provide suggestions for fixing issues
- Consider performance impact
- Test both success and failure cases

### Example Test Implementation

```lua
function TestSuite.TestNewFeature()
    SafeCall(function()
        -- Test setup
        local testData = CreateTestData()
        
        -- Execute test
        local result = NewFeature.Execute(testData)
        
        -- Validate results
        Assert(result.success, "NewFeature executes successfully", 'FEATURE')
        Assert(result.data ~= nil, "NewFeature returns data", 'FEATURE')
        Assert(#result.data > 0, "NewFeature returns valid data", 'FEATURE')
        
        return true
    end, 'FEATURE', 'New feature test')
end
```

---

## 📚 Additional Resources

### Documentation Links
- [BCC-Farming v2.5.0 Documentation](BCC_FARMING_DOCUMENTATION.md)
- [Enhanced Exports Documentation](BCC_FARMING_EXPORTS_V2.5.0.md)
- [Migration Guide](database_migration_v2.sql)
- [NUI System Documentation](NUI_SYSTEM_README.md)

### Support Channels
- Test failures: Check console logs first
- Performance issues: Review performance test results
- Configuration errors: Use configuration validator
- Database issues: Run migration validator

The BCC-Farming v2.5.0 testing suite provides comprehensive validation to ensure your enhanced farming system operates reliably and efficiently in production environments.