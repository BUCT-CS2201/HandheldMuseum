import { DynamicItem } from '../types/DynamicTypes';

type EventData = DynamicItem | string | number | boolean;
type EventCallback = (data: EventData) => void;

class EventHub {
  private static instance: EventHub;
  private events: Map<string, EventCallback[]> = new Map();

  private constructor() {}

  static getInstance(): EventHub {
    if (!EventHub.instance) {
      EventHub.instance = new EventHub();
    }
    return EventHub.instance;
  }

  on(event: string, callback: EventCallback): void {
    if (!this.events.has(event)) {
      this.events.set(event, []);
    }
    this.events.get(event)?.push(callback);
  }

  off(event: string, callback: EventCallback): void {
    if (!this.events.has(event)) return;
    const callbacks = this.events.get(event);
    if (callbacks) {
      const index = callbacks.indexOf(callback);
      if (index !== -1) {
        callbacks.splice(index, 1);
      }
    }
  }

  emit(event: string, data: EventData): void {
    if (!this.events.has(event)) return;
    this.events.get(event)?.forEach(callback => {
      callback(data);
    });
  }
}

export default EventHub.getInstance(); 