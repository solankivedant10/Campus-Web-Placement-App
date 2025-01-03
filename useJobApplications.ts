import { useState, useEffect } from 'react';
import { supabase } from '../lib/supabase';

export interface Application {
  id: string;
  job_id: string;
  status: string;
  created_at: string;
  job: {
    title: string;
    company_name: string;
  };
}

export function useJobApplications() {
  const [applications, setApplications] = useState<Application[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    fetchApplications();
  }, []);

  async function fetchApplications() {
    try {
      const { data, error } = await supabase
        .from('applications')
        .select(`
          *,
          job:jobs(title, company_name)
        `)
        .order('created_at', { ascending: false });

      if (error) throw error;
      setApplications(data || []);
    } catch (err) {
      setError(err instanceof Error ? err.message : 'An error occurred');
    } finally {
      setLoading(false);
    }
  }

  return { applications, loading, error, refetch: fetchApplications };
}