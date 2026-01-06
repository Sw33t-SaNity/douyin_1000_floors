using System;
using System.Collections.Generic;
using UnityEngine;
using Newtonsoft.Json;

namespace DouyinGame.Core
{
    /// <summary>
    /// Wrapper for JSON operations. Decouples your code from specific JSON libraries.
    /// </summary>
    public static class JsonHelper
    {
        public static string ToJson(object obj, bool indent = false)
        {
            return JsonConvert.SerializeObject(obj, indent ? Formatting.Indented : Formatting.None);
        }

        public static T FromJson<T>(string json)
        {
            if (string.IsNullOrEmpty(json)) return default;
            try
            {
                return JsonConvert.DeserializeObject<T>(json);
            }
            catch (Exception e)
            {
                Debug.LogError($"[JsonHelper] Parse Error: {e.Message}");
                return default;
            }
        }
    }

    /// <summary>
    /// Formatting tools for displaying Douyin stats (Likes, Money, Time).
    /// </summary>
    public static class FormatHelper
    {
        /// <summary>
        /// Formats large numbers into "1.2万" or "1.5亿" style.
        /// </summary>
        public static string FormatNumber(long number)
        {
            bool isNegative = number < 0;
            long absNumber = Math.Abs(number);

            string result;
            if (absNumber < 10000)
            {
                result = absNumber.ToString();
            }
            else if (absNumber < 100000000)
            {
                double wanValue = (double)absNumber / 10000;
                result = FormatDecimal(wanValue, 1) + "万";
            }
            else
            {
                double yiValue = (double)absNumber / 100000000.0;
                result = FormatDecimal(yiValue, 1) + "亿";
            }

            return isNegative ? "-" + result : result;
        }

        private static string FormatDecimal(double value, int maxDecimalPlaces)
        {
            if (value == (long)value) return ((long)value).ToString();

            int actualPlaces = maxDecimalPlaces;
            if (value >= 100) actualPlaces = 0;
            else if (value >= 10) actualPlaces = Mathf.Min(maxDecimalPlaces, 1);

            string result = value.ToString("F" + actualPlaces);
            if (result.Contains("."))
            {
                result = result.TrimEnd('0').TrimEnd('.');
            }
            return result;
        }

        public static string FormatTime(int totalSeconds)
        {
            totalSeconds = Mathf.Max(totalSeconds, 0);
            int minutes = (totalSeconds % 3600) / 60;
            int seconds = totalSeconds % 60;
            return $"{minutes:D2}:{seconds:D2}";
        }
    }

    /// <summary>
    /// Generic Math and List utilities.
    /// </summary>
    public static class MathHelper
    {
        public static int RandomInt(int min, int max) => UnityEngine.Random.Range(min, max);

        public static bool CheckProbability(int percentage)
        {
            return UnityEngine.Random.Range(0, 100) < percentage;
        }

        public static void ShuffleList<T>(IList<T> list)
        {
            System.Random rng = new System.Random();
            int n = list.Count;
            while (n > 1)
            {
                n--;
                int k = rng.Next(n + 1);
                (list[k], list[n]) = (list[n], list[k]);
            }
        }
    }
}