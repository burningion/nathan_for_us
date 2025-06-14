// Google Analytics Event Tracking for Nathan For Us
// This module provides easy-to-use functions for tracking custom events

window.Analytics = {
  // Track GIF interactions
  trackGifView: function(gifId, gifTitle) {
    if (typeof gtag !== 'undefined') {
      gtag('event', 'gif_view', {
        'custom_parameter_1': gifId,
        'custom_parameter_2': gifTitle || 'Untitled GIF',
        'event_category': 'engagement',
        'event_label': 'gif_interaction'
      });
    }
  },

  trackGifShare: function(gifId, gifTitle) {
    if (typeof gtag !== 'undefined') {
      gtag('event', 'gif_share', {
        'custom_parameter_1': gifId,
        'custom_parameter_2': gifTitle || 'Untitled GIF',
        'event_category': 'engagement',
        'event_label': 'gif_share'
      });
    }
  },

  // Track user registration
  trackSignUp: function(method = 'email') {
    if (typeof gtag !== 'undefined') {
      gtag('event', 'sign_up', {
        'method': method,
        'event_category': 'user_engagement'
      });
    }
  },

  // Track search activity
  trackSearch: function(searchTerm, resultCount = 0) {
    if (typeof gtag !== 'undefined') {
      gtag('event', 'search', {
        'search_term': searchTerm,
        'result_count': resultCount,
        'event_category': 'engagement'
      });
    }
  },

  // Track video timeline usage
  trackVideoTimelineUse: function(videoId, action = 'view') {
    if (typeof gtag !== 'undefined') {
      gtag('event', 'video_timeline_' + action, {
        'video_id': videoId,
        'event_category': 'content_interaction',
        'event_label': 'video_timeline'
      });
    }
  },

  // Track admin actions
  trackAdminAction: function(action, details = '') {
    if (typeof gtag !== 'undefined') {
      gtag('event', 'admin_action', {
        'action': action,
        'details': details,
        'event_category': 'admin',
        'event_label': 'admin_panel'
      });
    }
  },

  // Track page engagement time
  trackEngagement: function(pageName, timeSpent) {
    if (typeof gtag !== 'undefined') {
      gtag('event', 'page_engagement', {
        'page_name': pageName,
        'engagement_time': timeSpent,
        'event_category': 'engagement'
      });
    }
  }
};

// Auto-track page views for LiveView navigation
if (window.addEventListener) {
  window.addEventListener('phx:navigate', function(event) {
    if (typeof gtag !== 'undefined') {
      gtag('config', gtag.getGoogleAnalyticsId?.() || window.GA_MEASUREMENT_ID, {
        page_title: document.title,
        page_location: window.location.href
      });
    }
  });
}

console.log('📊 Nathan For Us Analytics loaded');