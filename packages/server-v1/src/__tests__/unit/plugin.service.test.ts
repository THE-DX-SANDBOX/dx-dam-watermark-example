import { PluginService } from '../../services/plugin.service';

describe('PluginService', () => {
  let service: PluginService;

  beforeEach(() => {
    service = new PluginService('test-api-key');
  });

  describe('validateApiKey', () => {
    it('should return true for valid API key', () => {
      const result = service.validateApiKey('test-api-key');
      expect(result).toBe(true);
    });

    it('should return false for invalid API key', () => {
      const result = service.validateApiKey('wrong-key');
      expect(result).toBe(false);
    });

    it('should return false for empty API key', () => {
      const result = service.validateApiKey('');
      expect(result).toBe(false);
    });
  });

  describe('processAsset', () => {
    it('should process asset and return result', async () => {
      const fileBuffer = Buffer.from('test file content');
      const metadata = {
        filename: 'test.jpg',
        mimeType: 'image/jpeg',
        size: 1024,
      };

      const result = await service.processAsset(fileBuffer, metadata);

      expect(result).toHaveProperty('tags');
      expect(result).toHaveProperty('metadata');
      expect(result).toHaveProperty('processingInfo');
      expect(Array.isArray(result.tags)).toBe(true);
    });

    it('should include processing time in result', async () => {
      const fileBuffer = Buffer.from('test file content');
      const metadata = {
        filename: 'test.jpg',
        mimeType: 'image/jpeg',
        size: 1024,
      };

      const result = await service.processAsset(fileBuffer, metadata);

      expect(result.processingInfo).toBeDefined();
      expect(result.processingInfo?.processingTime).toBeGreaterThan(0);
    });
  });
});
